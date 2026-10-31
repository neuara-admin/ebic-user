import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Result object encapsulating Razorpay checkout response.
class RazorpayPaymentResult {
  final bool isSuccess;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final int? errorCode;
  final String? errorMessage;

  const RazorpayPaymentResult.success({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  })  : isSuccess = true,
        errorCode = null,
        errorMessage = null;

  const RazorpayPaymentResult.failure({
    required this.errorCode,
    required this.errorMessage,
  })  : isSuccess = false,
        paymentId = null,
        orderId = null,
        signature = null;
}

/// Service managing the Razorpay Flutter Checkout lifecycle.
class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  Razorpay? _razorpay;
  Completer<RazorpayPaymentResult>? _activeCompleter;
  String? _currentKey;
  String? _currentOrderId;

  void _init() {
    if (_razorpay == null) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint(
      '[Razorpay] Payment Success: orderId=${response.orderId}',
    );

    // Simulated IDs/signatures exist only for local development. A release
    // build always forwards exactly what Razorpay returned for server checks.
    final isTest = kDebugMode &&
        ((_currentKey != null && _currentKey!.startsWith('rzp_test_')) ||
            (_currentOrderId != null && _currentOrderId!.startsWith('sim_')));

    final effectivePaymentId = response.paymentId ??
        (isTest ? 'pay_sim_${DateTime.now().millisecondsSinceEpoch}' : null);

    final effectiveOrderId = response.orderId ?? _currentOrderId;

    // In Razorpay test mode (e.g. clicking 'Success' on test modal without order_id),
    // SDK returns null/empty signature and null order_id. We supply a test signature
    // starting with 'sim_' so both test-mode and simulated backend verification succeed.
    final effectiveSignature = (response.signature != null && response.signature!.isNotEmpty)
        ? response.signature
        : (isTest
            ? 'sim_test_signature_$effectivePaymentId'
            : response.signature);

    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(RazorpayPaymentResult.success(
        paymentId: effectivePaymentId,
        orderId: effectiveOrderId,
        signature: effectiveSignature,
      ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[Razorpay] Payment Error: [${response.code}] ${response.message}');
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(RazorpayPaymentResult.failure(
        errorCode: response.code,
        errorMessage: response.message ?? 'Payment was cancelled or failed.',
      ));
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[Razorpay] External Wallet Selected: ${response.walletName}');
    // For external wallet, treat as pending or message user
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(RazorpayPaymentResult.failure(
        errorCode: 0,
        errorMessage: 'Selected external wallet: ${response.walletName}. Please complete payment via wallet.',
      ));
    }
  }

  /// Opens Razorpay checkout modal with the authoritative backend order details.
  Future<RazorpayPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required num amountPaise,
    String? currency = 'INR',
    required String name,
    required String description,
    String? prefillContact,
    String? prefillEmail,
    String? themeColorHex = '#10B981', // AppColors.primary
  }) async {
    _init();

    // Cancel any previous pending session
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(const RazorpayPaymentResult.failure(
        errorCode: -1,
        errorMessage: 'New payment session initiated.',
      ));
    }

    _activeCompleter = Completer<RazorpayPaymentResult>();

    final isUnconfigured = keyId.isEmpty || keyId == 'rzp_test_simulated';
    if (kReleaseMode && (isUnconfigured || !orderId.startsWith('order_'))) {
      // The backend could not create a real Razorpay order. Never fall back to
      // a test key or an order-less checkout in production.
      _activeCompleter!.complete(const RazorpayPaymentResult.failure(
        errorCode: -3,
        errorMessage: 'Payments are temporarily unavailable. You have not been charged. Please try again shortly.',
      ));
      return _activeCompleter!.future;
    }

    final effectiveKey = isUnconfigured ? 'rzp_test_Tb32WMsZscKtDf' : keyId;

    _currentKey = effectiveKey;
    _currentOrderId = orderId;

    final options = <String, dynamic>{
      'key': effectiveKey,
      'amount': amountPaise.toInt(),
      'name': name,
      'description': description,
      if (orderId.isNotEmpty && orderId.startsWith('order_')) 'order_id': orderId,
      'currency': currency ?? 'INR',
      'prefill': {
        if (prefillContact != null && prefillContact.isNotEmpty)
          'contact': prefillContact,
        if (prefillEmail != null && prefillEmail.isNotEmpty)
          'email': prefillEmail,
      },
      'theme': {
        'color': themeColorHex ?? '#10B981',
      },
      'retry': {'enabled': true, 'max_count': 1},
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('[Razorpay] Exception opening checkout: $e');
      if (!_activeCompleter!.isCompleted) {
        _activeCompleter!.complete(RazorpayPaymentResult.failure(
          errorCode: -2,
          errorMessage: 'Unable to open the payment screen. You have not been charged. Please try again.',
        ));
      }
    }

    return _activeCompleter!.future;
  }

  /// Clean up listeners when done.
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
