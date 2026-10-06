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

  // Chef picked on Review Booking; cleared if the customer switches to
  // auto-assign after that chef became unavailable.
  late String? _preferredChefId = widget.checkoutData['preferredChefId']?.toString();
  late String? _chefName = widget.checkoutData['chefName']?.toString();

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

  /// Only a Chef Menu (catalogue) booking came from the cart; a diet-plan
  /// booking must leave whatever the customer has in the cart untouched.
  bool get _isCatalogueBooking =>
      widget.checkoutData['mode'] != 'ASSIGNED_MEAL' &&
      widget.checkoutData['bookingFlow'] != 'ASSIGNED_MEAL';

  double get _effectiveFinalAmount {
    final rawQuote = widget.checkoutData['quote'];
    if (rawQuote is QuoteModel) {
      return rawQuote.total;
    } else if (rawQuote is Map) {
      final t = rawQuote['total'] ?? rawQuote['grandTotal'];
      if (t is num) return t.toDouble();
    }
    final rawAmount =
        widget.checkoutData['finalAmount'] ?? widget.checkoutData['total'];
    if (rawAmount is num) return rawAmount.toDouble();
    return 0.0;
  }

  /// The picked chef was booked/went off duty between Review and Pay: let
  /// the customer pick again or continue with auto-assign. Nothing has been
  /// charged or created at this point.
  Future<void> _handlePreferredChefUnavailable(String message) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Chef no longer available',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pick'),
            child: const Text('Pick another chef'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'auto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Auto-assign & pay'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'pick') {
      Navigator.pop(context, 'chef_unavailable');
    } else if (choice == 'auto') {
      setState(() {
        _preferredChefId = null;
        _chefName = 'Nearest available certified chef';
      });
      await _handlePayment();
    }
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

      // 3. Create the order from the accepted quote — the backend cooks
      // exactly the quoted dishes and charges exactly the quoted total.
      final quoteId =
          widget.checkoutData['quoteId']?.toString() ??
          widget.checkoutData['quote_id']?.toString() ??
          quote?.quoteId;
      if (quoteId == null || quoteId.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Your price quote is missing. Please go back and review your booking.';
        });
        return;
      }

      final orderRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orders,
        body: {
          'addressId': addressId,
          'bookingOption': bookingOption,
          'memberIds': validMemberIds,
          'quoteId': quoteId,
          if (_preferredChefId != null) 'preferredChefId': _preferredChefId,
        },
      );
      if (orderRes.error?.code == 'PREFERRED_CHEF_UNAVAILABLE') {
        setState(() => _isProcessing = false);
        await _handlePreferredChefUnavailable(orderRes.error!.message);
        return;
      }
      if (!orderRes.success || orderRes.data == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              orderRes.error?.message ??
              orderRes.message ??
              'Failed to initialize chef booking order.';
        });
        return;
      }
      final orderData = orderRes.data!;

      orderId = orderData['id']?.toString();
      if (orderId == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Server did not return a valid order reference.';
        });
        return;
      }

      final dishes = (widget.checkoutData['dishes'] as List<dynamic>?) ?? [];

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

      // The backend's final price is authoritative: when it says nothing is
      // payable, confirm — never open Razorpay for a ₹0 order, even if the
      // earlier quote shown on screen differed.
      if (!backendRequiresPayment) {
        if (_isCatalogueBooking) CartService().clear();
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
                _chefName ?? 'Certified Home Chef',
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

      // Wallet (and backend-settled) payments are already SUCCEEDED by
      // initiate — no gateway, no second verify round-trip.
      final alreadySettled = payData['status']?.toString() == 'SUCCEEDED';

      if (!alreadySettled && _selectedMethod == 'GATEWAY') {
        final razorpayKey =
            payData['keyId']?.toString() ?? payData['key']?.toString();
        final razorpayOrderId = payData['gatewayOrderId']?.toString();
        final amountPaise = payData['amountPaise'] as num?;
        if (razorpayKey == null ||
            razorpayOrderId == null ||
            razorpayOrderId.isEmpty ||
            amountPaise == null) {
          throw Exception('Payment could not be started. Please try again.');
        }

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

        final gatewayPaymentId = checkoutRes.paymentId;
        if (gatewayPaymentId == null || gatewayPaymentId.isEmpty) {
          throw Exception('Payment was not completed. Please try again.');
        }

        // Authoritative verify — a booking is only confirmed if the backend
        // confirms Razorpay actually captured this payment for this order.
        final verifyRes = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.orderPayVerify(orderId),
          body: {
            'gatewayPaymentId': gatewayPaymentId,
            'gatewaySignature': checkoutRes.signature ?? '',
          },
          requiresIdempotency: true,
          explicitIdempotencyKey: idempotencyKey,
        );
        if (!verifyRes.success) {
          throw Exception(
            verifyRes.error?.message ??
                verifyRes.message ??
                'We could not confirm your payment. If you were charged, contact support.',
          );
        }
      } else if (!alreadySettled) {
        throw Exception(
          'Your wallet payment could not be completed. Please try again.',
        );
      }

      // 6. Clear cart and reset state
      if (_isCatalogueBooking) CartService().clear();

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
          'chefName': _chefName ?? 'Certified Home Chef',
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
              if (_chefName != null) ...[
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
                              _chefName ??
                                  'Certified Home Chef',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _preferredChefId != null
                                  ? 'Your chosen chef · confirmed after payment'
                                  : 'Assigned automatically after payment',
                              style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF047857),
                      Color(0xFF059669),
                    ],
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

              // Nothing to pay: no gateway or wallet choice — the backend
              // confirms the booking directly.
              if (finalAmount <= 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.emerald700.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: AppColors.emerald700),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fully covered — no payment needed for this booking.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
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
                  hasEnoughWallet
                      ? 'Pay instantly from your wallet balance'
                      : 'Insufficient balance (₹${_walletBalance.toStringAsFixed(0)}). Please use Razorpay.',
                  Icons.account_balance_wallet_outlined,
                  isWarning: !hasEnoughWallet,
                  enabled: hasEnoughWallet && !_isLoadingWallet,
                ),
              ],
              const SizedBox(height: 32),

              EbicButton(
                label: finalAmount <= 0
                    ? 'Confirm Booking'
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
    bool enabled = true,
  }) {
    final isSelected = _selectedMethod == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primarySubtle.withOpacity(0.35))
                : (isDark ? AppColors.slate900 : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.slate800 : AppColors.slate200),
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
                        color: isSelected
                            ? AppColors.primarySubtle
                            : (isDark ? AppColors.slate800 : AppColors.slate100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.slate400 : AppColors.slate600),
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
                                  ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                  : (isDark ? Colors.white : AppColors.slate900),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: isWarning
                                  ? AppColors.danger
                                  : (isDark ? AppColors.slate400 : AppColors.slate500),
                              fontSize: 12,
                              fontWeight: isWarning
                                  ? FontWeight.w500
                                  : FontWeight.normal,
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
        ),
      ),
    );
  }
}
