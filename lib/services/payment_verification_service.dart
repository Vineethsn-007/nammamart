import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class PaymentVerificationService {
  static const String _baseUrl = 'https://api.razorpay.com/v1';

  /// Verify payment signature to ensure payment authenticity
  static bool verifyPaymentSignature({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    try {
      final String expectedSignature = _generateSignature(
        orderId + '|' + paymentId,
        ApiConstants.razorpaySecret,
      );

      return expectedSignature == signature;
    } catch (e) {
      print('Error verifying payment signature: $e');
      return false;
    }
  }

  /// Generate HMAC SHA256 signature
  static String _generateSignature(String payload, String secret) {
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Capture payment automatically (server-side)
  static Future<Map<String, dynamic>> capturePayment({
    required String paymentId,
    required int amount,
    String? currency,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/payments/$paymentId/capture');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${ApiConstants.razorpayKey}:${ApiConstants.razorpaySecret}'))}',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency ?? 'INR',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to capture payment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error capturing payment: $e');
      rethrow;
    }
  }

  /// Get payment details from Razorpay
  static Future<Map<String, dynamic>> getPaymentDetails(
      String paymentId) async {
    try {
      final url = Uri.parse('$_baseUrl/payments/$paymentId');

      final response = await http.get(
        url,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${ApiConstants.razorpayKey}:${ApiConstants.razorpaySecret}'))}',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to get payment details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting payment details: $e');
      rethrow;
    }
  }

  /// Verify payment status and ensure it's captured
  static Future<bool> verifyPaymentCapture(String paymentId) async {
    try {
      final paymentDetails = await getPaymentDetails(paymentId);

      // Check if payment is captured
      final status = paymentDetails['status'] as String?;
      final captured = paymentDetails['captured'] as bool?;

      return status == 'captured' && captured == true;
    } catch (e) {
      print('Error verifying payment capture: $e');
      return false;
    }
  }

  /// Create a Razorpay order (optional - for better tracking)
  static Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/orders');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${ApiConstants.razorpayKey}:${ApiConstants.razorpaySecret}'))}',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'receipt': receipt,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to create order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }
}
