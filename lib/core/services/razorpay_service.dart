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

  void _init() {
    if (_razorpay == null) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('[Razorpay] Payment Success: ${response.paymentId}');
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(RazorpayPaymentResult.success(
        paymentId: response.paymentId,
        orderId: response.orderId,
        signature: response.signature,
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

    final options = {
      'key': keyId,
      'amount': amountPaise.toInt(),
      'name': name,
      'description': description,
      'order_id': orderId,
      'currency': currency ?? 'INR',
      'timeout': 300, // 5 minutes validity
      'prefill': {
        if (prefillContact != null && prefillContact.isNotEmpty) 'contact': prefillContact,
        if (prefillEmail != null && prefillEmail.isNotEmpty) 'email': prefillEmail,
      },
      'theme': {
        'color': themeColorHex ?? '#10B981',
      },
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('[Razorpay] Exception opening checkout: $e');
      if (!_activeCompleter!.isCompleted) {
        _activeCompleter!.complete(RazorpayPaymentResult.failure(
          errorCode: -2,
          errorMessage: 'Unable to launch payment gateway: $e',
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
