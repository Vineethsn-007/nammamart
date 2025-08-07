# Razorpay Production Setup Guide

## Overview

This guide will help you configure your Flutter app to use Razorpay production API keys instead of test keys.

## Files Modified

1. `lib/utils/constants.dart` - New configuration file
2. `lib/services/razorpay_service.dart` - Updated to use constants
3. `lib/screens/checkout_screen.dart` - Updated to use constants

## Steps to Configure Production Keys

### 1. Update API Keys

Open `lib/utils/constants.dart` and replace the placeholder values:

```dart
class ApiConstants {
  // Replace these with your actual production keys
  static const String razorpayKeyId = 'rzp_live_YOUR_ACTUAL_PRODUCTION_KEY_ID';
  static const String razorpayKeySecret = 'YOUR_ACTUAL_PRODUCTION_SECRET_KEY';

  // Set this to false for production
  static const bool isTestMode = false;
}
```

### 2. Get Your Production Keys

1. Log in to your Razorpay Dashboard
2. Go to Settings → API Keys
3. Copy your Live Mode Key ID (starts with `rzp_live_`)
4. Copy your Live Mode Secret Key
5. Replace the placeholder values in `constants.dart`

### 3. Environment Configuration

The `isTestMode` flag controls which keys are used:

- `true` = Uses test keys (for development)
- `false` = Uses production keys (for live app)

### 4. Security Best Practices

- Never commit API keys to version control
- Consider using environment variables or secure storage
- Keep your secret key confidential
- Use different keys for development and production

### 5. Testing

1. Set `isTestMode = true` for testing
2. Test payments with small amounts
3. Verify webhook configurations
4. Set `isTestMode = false` for production release

## Important Notes

### Webhook Configuration

Make sure to configure webhooks in your Razorpay dashboard:

- Go to Settings → Webhooks
- Add your webhook URL
- Select events: `payment.captured`, `payment.failed`

### Server-Side Integration

For complete security, consider implementing server-side payment verification:

1. Create payment orders on your server
2. Verify payment signatures
3. Handle webhook events

### Error Handling

The app includes error handling for:

- Network issues
- Payment failures
- Invalid amounts
- Missing required fields

## Verification Checklist

- [ ] Production keys are correctly set in `constants.dart`
- [ ] `isTestMode` is set to `false`
- [ ] Webhooks are configured in Razorpay dashboard
- [ ] Test payments work correctly
- [ ] Error handling is working
- [ ] App is ready for production release

## Support

If you encounter issues:

1. Check Razorpay dashboard for payment status
2. Verify API key permissions
3. Test with small amounts first
4. Review error logs in the app
