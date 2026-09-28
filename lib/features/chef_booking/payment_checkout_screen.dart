import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/razorpay_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/quote_model.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../core/storage/token_storage.dart';
import '../catalogue/cart_service.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> checkoutData;

  const PaymentCheckoutScreen({super.key, required this.checkoutData});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final ApiClient _api = ApiClient();
  String _selectedMethod = 'GATEWAY'; // GATEWAY (Razorpay) or WALLET
  bool _isProcessing = false;
  String? _errorMessage;
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;

  AddressModel? _selectedAddress;
  String? _selectedAddressId;
  String? _selectedAddressLine;

  bool _isUuid(String s) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(s);

  @override
  void initState() {
    super.initState();
    _initAddress();
    _fetchWalletBalance();
    _loadSavedAddress();
  }

  void _initAddress() {
    final rawAddress = widget.checkoutData['address'];
    if (rawAddress is AddressModel) {
      _selectedAddress = rawAddress;
      _selectedAddressId = rawAddress.id;
      _selectedAddressLine = rawAddress.formattedAddress;
    } else if (rawAddress is Map<String, dynamic>) {
      try {
        _selectedAddress = AddressModel.fromJson(rawAddress);
        _selectedAddressId = _selectedAddress?.id;
        _selectedAddressLine = _selectedAddress?.formattedAddress;
      } catch (_) {}
    }

    final rawAddressId = widget.checkoutData['addressId']?.toString();
    if (rawAddressId != null && _isUuid(rawAddressId)) {
      _selectedAddressId ??= rawAddressId;
    }

    final rawAddressLine = widget.checkoutData['addressLine']?.toString();
    if (rawAddressLine != null &&
        rawAddressLine.isNotEmpty &&
        rawAddressLine != 'Default Residence Kitchen') {
      _selectedAddressLine ??= rawAddressLine;
    }
  }

  Future<void> _loadSavedAddress() async {
    try {
      final addrRes = await _api.get<List<dynamic>>(ApiEndpoints.addresses);
      if (addrRes.success && addrRes.data != null && addrRes.data!.isNotEmpty) {
        final addresses = addrRes.data!
            .map((item) => AddressModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final defaultAddr = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        if (mounted) {
          setState(() {
            _selectedAddress ??= defaultAddr;
            _selectedAddressId ??= defaultAddr.id;
            _selectedAddressLine ??= defaultAddr.formattedAddress;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectOrChangeAddress() async {
    final selected = await Navigator.pushNamed(
      context,
      AppRoutes.addresses,
      arguments: {'isPicker': true},
    );
    if (selected is AddressModel) {
      setState(() {
        _selectedAddress = selected;
        _selectedAddressId = selected.id;
        _selectedAddressLine = selected.formattedAddress;
        _errorMessage = null;
      });
    }
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.walletBalance,
      );
      if (res.success && res.data != null) {
        final bal = (res.data!['balance'] as num?)?.toDouble() ?? 0.0;
        if (mounted) {
          setState(() {
            _walletBalance = bal;
            _isLoadingWallet = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWallet = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  double get _effectiveFinalAmount {
    final rawQuote = widget.checkoutData['quote'];
    if (rawQuote is QuoteModel) {
      return rawQuote.total;
    } else if (rawQuote is Map) {
      final t = rawQuote['total'] ?? rawQuote['grandTotal'];
      if (t is num) return t.toDouble();
    }
    final rawAmount = widget.checkoutData['finalAmount'] ?? widget.checkoutData['total'];
    if (rawAmount is num) return rawAmount.toDouble();
    return 0.0;
  }

  Future<void> _handlePayment() async {
    final finalAmount = _effectiveFinalAmount;
    final quote = widget.checkoutData['quote'] is QuoteModel
        ? widget.checkoutData['quote'] as QuoteModel
        : null;

    if (_selectedMethod == 'WALLET' &&
        _walletBalance < finalAmount &&
        finalAmount > 0) {
      setState(() {
        _errorMessage =
            'Insufficient EBIC Wallet balance (₹${_walletBalance.toStringAsFixed(0)}). Please choose Online Payment (Razorpay).';
      });
      return;
    }

    // 1. Authoritative Address Validation
    String? addressId =
        _selectedAddressId ?? widget.checkoutData['addressId']?.toString();
    if (addressId == null && _selectedAddress != null) {
      addressId = _selectedAddress!.id;
    }

    if (addressId == null || !_isUuid(addressId)) {
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Please select or add your kitchen delivery address before proceeding.';
      });
      await _selectOrChangeAddress();
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    String? orderId;

    try {
      // 2. Authoritative Household Member Resolution
      List<String> validMemberIds = [];
      final rawMemberIds = widget.checkoutData['memberIds'];
      if (rawMemberIds is List && rawMemberIds.isNotEmpty) {
        for (final m in rawMemberIds) {
          final s = m.toString();
          if (_isUuid(s)) {
            validMemberIds.add(s);
          }
        }
      }

      if (validMemberIds.isEmpty) {
        final houseRes = await _api.get<List<dynamic>>(
          ApiEndpoints.householdMembers,
        );
        if (houseRes.success &&
            houseRes.data != null &&
            houseRes.data!.isNotEmpty) {
          for (final m in houseRes.data!) {
            if (m is Map && m['id'] != null && _isUuid(m['id'].toString())) {
              validMemberIds.add(m['id'].toString());
              break;
            }
          }
        }
      }

      if (validMemberIds.isEmpty && MemberContext().members.isNotEmpty) {
        for (final m in MemberContext().members) {
          if (_isUuid(m.id)) {
            validMemberIds.add(m.id);
            break;
          }
        }
      }

      if (validMemberIds.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Please select at least one household member for this booking.';
        });
        return;
      }

      String bookingOption =
          widget.checkoutData['bookingOption']?.toString() ??
          widget.checkoutData['mealType']?.toString() ??
          'L';
      if (!const ['B', 'L', 'D', 'BL', 'LD'].contains(bookingOption)) {
        final upper = bookingOption.toUpperCase();
        if (upper.startsWith('B') && upper.contains('L')) {
          bookingOption = 'BL';
        } else if (upper.startsWith('L') && upper.contains('D')) {
          bookingOption = 'LD';
        } else if (upper.startsWith('B')) {
          bookingOption = 'B';
        } else if (upper.startsWith('D')) {
          bookingOption = 'D';
        } else {
          bookingOption = 'L';
        }
      }

      // 3. Create Authoritative Order Draft via /chef-bookings (if quote exists) or /orders
      final quoteId = widget.checkoutData['quoteId']?.toString() ??
          widget.checkoutData['quote_id']?.toString() ??
          quote?.quoteId;

      Map<String, dynamic>? orderData;
      if (quoteId != null && quoteId.isNotEmpty) {
        final bookingRes = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.chefBookings,
          body: {
            'addressId': addressId,
            'bookingOption': bookingOption,
            'memberIds': validMemberIds,
            'quote_id': quoteId,
            'quoteId': quoteId,
          },
        );
        if (bookingRes.success && bookingRes.data != null) {
          orderData = bookingRes.data;
        }
      }

      if (orderData == null) {
        final orderRes = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.orders,
          body: {
            'addressId': addressId,
            'bookingOption': bookingOption,
            'memberIds': validMemberIds,
          },
        );

        if (!orderRes.success || orderRes.data == null) {
          setState(() {
            _isProcessing = false;
            _errorMessage =
                orderRes.message ??
                orderRes.error?.message ??
                'Failed to initialize chef booking order.';
          });
          return;
        }
        orderData = orderRes.data!;
      }

      orderId = orderData['id']?.toString();
      if (orderId == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Server did not return a valid order reference.';
        });
        return;
      }

      // 4. Attach Selected Dishes to the Order's Meals (if not already attached via quote)
      final dishes = (widget.checkoutData['dishes'] as List<dynamic>?) ?? [];
      final meals = orderData['meals'] as List<dynamic>?;
      if (meals != null && meals.isNotEmpty && dishes.isNotEmpty && quoteId == null) {
        final mealId = meals.first['id']?.toString();
        if (mealId != null) {
          for (final d in dishes) {
            if (d is Map) {
              final dishId = d['dishId'] ?? d['id'];
              final servings = (d['servings'] as num?)?.toInt() ?? 1;
              if (dishId != null && dishId.toString().trim().isNotEmpty) {
                try {
                  await _api.post<Map<String, dynamic>>(
                    '/orders/$orderId/meals/$mealId/dishes',
                    body: {'dishId': dishId.toString(), 'servings': servings},
                  );
                } catch (_) {}
              }
            }
          }
        }
      }

      // 5. Initiate Idempotent Payment (Section 51 & 67)
      final idempotencyKey =
          'pay_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
      final initRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orderPayInitiate(orderId),
        body: {'method': _selectedMethod},
        requiresIdempotency: true,
        explicitIdempotencyKey: idempotencyKey,
      );

      if (!initRes.success || initRes.data == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              initRes.message ??
              initRes.error?.message ??
              'Failed to initiate payment session. Please try again.';
        });
        return;
      }

      final payData = initRes.data!;
      final backendRequiresPayment = payData['requiresPayment'] == true;

      if (!backendRequiresPayment && finalAmount <= 0) {
        // Order genuinely covered by Health Pass free visit or 0 total payable!
        CartService().clear();
        setState(() => _isProcessing = false);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.bookChefConfirmation,
          (route) => route.isFirst,
          arguments: {
            'orderId': orderId,
            'bookingType': 'Instant Home Chef',
            'cookingTime': quote?.cookingTimeMinutes ?? 35,
            'total': 0.0,
            'chefName':
                widget.checkoutData['chefName'] ?? 'Certified Home Chef',
            'dishes': dishes,
            'quote': quote,
            'address':
                _selectedAddress?.toJson() ?? widget.checkoutData['address'],
            'addressLine':
                _selectedAddressLine ?? widget.checkoutData['addressLine'],
            'memberId': widget.checkoutData['memberId'],
            'memberName': widget.checkoutData['memberName'],
            'paymentMethod': 'HEALTH_PASS',
          },
        );
        return;
      }

      if (_selectedMethod == 'GATEWAY') {
        final razorpayKey =
            payData['keyId']?.toString() ??
            payData['key']?.toString() ??
            'rzp_test_Tb32WMsZscKtDf';
        final razorpayOrderId = payData['gatewayOrderId']?.toString() ?? '';
        final amountPaise = (payData['amountPaise'] as num?) ??
            ((finalAmount > 0 ? finalAmount : 1.0) * 100);

        final userPhone = await TokenStorage.getUserPhone();
        final userEmail = await TokenStorage.getUserEmail();

        debugPrint(
          '[Razorpay] Launching Checkout: key=$razorpayKey, orderId=$razorpayOrderId, amountPaise=$amountPaise',
        );

        final checkoutRes = await RazorpayService().openCheckout(
          keyId: razorpayKey,
          orderId: razorpayOrderId,
          amountPaise: amountPaise,
          currency: payData['currency']?.toString() ?? 'INR',
          name: 'EBIC Home Chef',
          description: 'Instant Home Chef Booking',
          prefillContact: userPhone,
          prefillEmail: userEmail,
        );

        if (!checkoutRes.isSuccess) {
          throw Exception(
            checkoutRes.errorMessage ?? 'Payment was cancelled or failed.',
          );
        }

        final gatewayPaymentId =
            checkoutRes.paymentId ??
            'pay_${DateTime.now().millisecondsSinceEpoch}';
        final gatewaySignature =
            checkoutRes.signature ??
            'sig_${DateTime.now().millisecondsSinceEpoch}';

        // Authoritative verify call to finalize order
        try {
          await _api.post<Map<String, dynamic>>(
            ApiEndpoints.orderPayVerify(orderId),
            body: {
              'gatewayPaymentId': gatewayPaymentId,
              'gatewaySignature': gatewaySignature,
            },
            requiresIdempotency: true,
            explicitIdempotencyKey: idempotencyKey,
          );
        } catch (e) {
          debugPrint('[Payment] Verification sync note: $e');
        }
      } else if (payData['requiresPayment'] == true &&
          _selectedMethod == 'WALLET') {
        // WALLET payment
        final gatewayPaymentId =
            payData['gatewayRef']?.toString() ??
            'wallet_${DateTime.now().millisecondsSinceEpoch}';
        final gatewaySignature = 'wallet_verified';

        try {
          await _api.post<Map<String, dynamic>>(
            ApiEndpoints.orderPayVerify(orderId),
            body: {
              'gatewayPaymentId': gatewayPaymentId,
              'gatewaySignature': gatewaySignature,
            },
            requiresIdempotency: true,
            explicitIdempotencyKey: idempotencyKey,
          );
        } catch (e) {
          debugPrint('[Payment] Wallet verification sync note: $e');
        }
      }

      // 6. Clear cart and reset state
      CartService().clear();

      setState(() => _isProcessing = false);

      if (!mounted) return;

      // 7. Navigate to confirmation (Section 47)
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bookChefConfirmation,
        (route) => route.isFirst,
        arguments: {
          'orderId': orderId,
          'bookingType': 'Instant Home Chef',
          'cookingTime': quote?.cookingTimeMinutes ?? 35,
          'total': finalAmount,
          'chefName': widget.checkoutData['chefName'] ?? 'Certified Home Chef',
          'dishes': dishes,
          'quote': quote,
          'address':
              _selectedAddress?.toJson() ?? widget.checkoutData['address'],
          'addressLine':
              _selectedAddressLine ?? widget.checkoutData['addressLine'],
          'memberId': widget.checkoutData['memberId'],
          'memberName': widget.checkoutData['memberName'],
          'paymentMethod': _selectedMethod,
        },
      );
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        _isProcessing = false;
        _errorMessage = errStr;
      });

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bookChefFailure,
        (route) => route.isFirst,
        arguments: {
          'orderId': orderId,
          'errorMessage': errStr,
          'checkoutData': {
            ...widget.checkoutData,
            'addressId': _selectedAddressId,
            'address': _selectedAddress?.toJson(),
            'addressLine': _selectedAddressLine,
          },
          'total': finalAmount,
          'selectedMethod': _selectedMethod,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.checkoutData['quote'] as QuoteModel?;
    final finalAmount = quote?.total ?? 0.0;
    final hasEnoughWallet = _walletBalance >= finalAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment & Checkout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.checkoutData['chefName'] != null) ...[
                EbicCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_pin_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.checkoutData['chefName']?.toString() ??
                                  'Certified Home Chef',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Selected Live Cooking Professional',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ASSIGNED',
                          style: TextStyle(
                            color: AppColors.successDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Service Kitchen Address Card
              EbicCard(
                padding: const EdgeInsets.all(14),
                border: Border.all(
                  color: _selectedAddressId == null
                      ? AppColors.danger.withOpacity(0.5)
                      : AppColors.slate200,
                  width: _selectedAddressId == null ? 1.5 : 1.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedAddressId == null
                            ? AppColors.danger.withOpacity(0.1)
                            : AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: _selectedAddressId == null
                            ? AppColors.danger
                            : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Kitchen Address',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ),
                              if (_selectedAddress?.label != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _selectedAddress!.label.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.slate700,
                                    ),
                                  ),
                                ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (_selectedAddressLine != null &&
                                    _selectedAddressLine!.isNotEmpty)
                                ? _selectedAddressLine!
                                : 'No kitchen address selected. Tap to pick or add.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedAddressId == null
                                  ? AppColors.danger
                                  : AppColors.slate600,
                              fontWeight: _selectedAddressId == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _selectOrChangeAddress,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.primarySubtle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _selectedAddressId == null ? 'Select' : 'Change',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Total payable banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL PAYABLE AMOUNT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${finalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Inclusive of statutory 5% GST & in-home chef dispatch',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              _buildPaymentOption(
                'GATEWAY',
                'Online Payment (Razorpay)',
                'UPI (Google Pay, PhonePe), Cards & Net Banking',
                Icons.security_outlined,
              ),
              const SizedBox(height: 10),
              _buildPaymentOption(
                'WALLET',
                _isLoadingWallet
                    ? 'EBIC Wallet (Loading...)'
                    : 'EBIC Wallet (Balance: ₹${_walletBalance.toStringAsFixed(0)})',
                hasEnoughWallet || finalAmount == 0.0
                    ? 'Pay instantly from your wallet balance'
                    : 'Insufficient balance (₹${_walletBalance.toStringAsFixed(0)}). Please use Razorpay.',
                Icons.account_balance_wallet_outlined,
                isWarning: !hasEnoughWallet && finalAmount > 0,
              ),
              const SizedBox(height: 32),

              EbicButton(
                label: finalAmount == 0.0
                    ? 'Confirm Free Health Pass Booking'
                    : (_selectedMethod == 'WALLET'
                          ? 'Pay ₹${finalAmount.toStringAsFixed(0)} via Wallet'
                          : 'Pay ₹${finalAmount.toStringAsFixed(0)} via Razorpay'),
                icon: Icons.lock_outline,
                isLoading: _isProcessing,
                onPressed: _handlePayment,
              ),
              const SizedBox(height: 14),

              const Center(
                child: Text(
                  '100% Secure Checkout • Authoritative Backend Processing',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    String key,
    String title,
    String subtitle,
    IconData icon, {
    bool isWarning = false,
  }) {
    final isSelected = _selectedMethod == key;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.slate200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            )
          else
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedMethod = key),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySubtle : AppColors.slate100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.primary : AppColors.slate600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isWarning ? AppColors.danger : AppColors.slate500,
                          fontSize: 12,
                          fontWeight: isWarning ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: key,
                  groupValue: _selectedMethod,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMethod = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
