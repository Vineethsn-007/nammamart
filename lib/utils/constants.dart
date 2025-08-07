class ApiConstants {
  // Razorpay Configuration
  static const String razorpayKeyId =
      'rzp_live_A9pZcJpeWM9n71'; // Replace with your production key
  static const String razorpayKeySecret =
      'Zo7JpIwEJ27TilQpBotmMdj9'; // Replace with your production secret

  // Test keys (for development)
  static const String razorpayTestKeyId = 'rzp_test_qix9HDGt0k0hgJ';
  static const String razorpayTestKeySecret = 'YOUR_TEST_SECRET_KEY';

  // Environment flag - set to false for production
  static const bool isTestMode = false;

  // Get the appropriate key based on environment
  static String get razorpayKey =>
      isTestMode ? razorpayTestKeyId : razorpayKeyId;
  static String get razorpaySecret =>
      isTestMode ? razorpayTestKeySecret : razorpayKeySecret;
}

class AppConstants {
  static const String appName = 'NammaMart';
  static const String appDescription = 'Your local grocery store';

  // Payment related constants
  static const String currency = 'INR';
  static const String defaultPaymentDescription = 'Payment for your order';

  // Theme colors
  static const String primaryColorHex = '#4CAF50';
  static const String accentColorHex = '#FF9800';
}
