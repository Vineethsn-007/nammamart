import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../utils/constants.dart';

class RazorpayService {
  late Razorpay _razorpay;
  final Function(PaymentSuccessResponse) onSuccess;
  final Function(PaymentFailureResponse) onFailure;
  final Function(ExternalWalletResponse)? onWalletSelected;

  RazorpayService({
    required this.onSuccess,
    required this.onFailure,
    this.onWalletSelected,
  }) {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWalletSelected ?? (_) {});
  }

  void startPayment({
    required String orderId,
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
    required String color,
    String? currency,
    Map<String, dynamic>? notes,
  }) {
    try {
      // Ensure amount is valid
      if (amount <= 0) {
        throw Exception("Invalid amount: Amount must be greater than 0");
      }

      // Ensure required fields are not empty
      if (orderId.isEmpty || name.isEmpty || description.isEmpty) {
        throw Exception("Required fields cannot be empty");
      }

      // Payment options with automatic capture enabled
      var options = {
        'key': ApiConstants.razorpayKey,
        'amount': (amount * 100).toInt(),
        'name': name,
        'description': description,
        'prefill': {
          'contact': contact,
          'email': email,
        },
        'theme': {
          'color': color,
        },
        // Enable automatic capture to prevent refunds
        'capture': true,
        // Add order ID for tracking
        'order_id': orderId,
        // Set currency (default to INR)
        'currency': currency ?? 'INR',
        // Add notes for order tracking
        'notes': {
          'order_id': orderId,
          'source': 'namma_mart_app',
          ...?notes,
        },
      };

      // Open Razorpay checkout
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay Error: ${e.toString()}');

      // Create a failure response to pass to the error handler
      final failureResponse = PaymentFailureResponse(
          9999, // Custom error code for initialization errors
          "Failed to initialize payment: ${e.toString()}",
          {});

      // Call the failure callback
      onFailure(failureResponse);
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
