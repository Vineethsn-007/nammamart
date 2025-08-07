# Razorpay Automatic Payment Capture Guide

## Overview

This guide explains how to implement automatic payment capture in your Flutter app to prevent refunds and ensure payments are properly processed.

## What is Automatic Capture?

### Manual vs Automatic Capture

- **Manual Capture**: Payment is authorized but not captured immediately. You must manually capture it later.
- **Automatic Capture**: Payment is captured immediately upon successful authorization, preventing refunds.

### Why Use Automatic Capture?

1. **Prevents Refunds**: Once captured, payments cannot be automatically refunded
2. **Immediate Processing**: Orders are processed immediately after payment
3. **Better User Experience**: No delays in order confirmation
4. **Reduced Chargebacks**: Captured payments are less likely to be disputed

## Implementation Details

### 1. Updated Razorpay Service (`lib/services/razorpay_service.dart`)

**Key Changes:**

- Added `'capture': true` to payment options
- Added `'order_id'` for better tracking
- Enhanced notes with order tracking information

```dart
var options = {
  'key': ApiConstants.razorpayKey,
  'amount': (amount * 100).toInt(),
  'name': name,
  'description': description,
  'capture': true, // Enable automatic capture
  'order_id': orderId, // Add order tracking
  'currency': currency ?? 'INR',
  'notes': {
    'order_id': orderId,
    'source': 'namma_mart_app',
    ...?notes,
  },
};
```

### 2. Payment Verification Service (`lib/services/payment_verification_service.dart`)

**Features:**

- **Signature Verification**: Ensures payment authenticity
- **Capture Verification**: Checks if payment is captured
- **Manual Capture**: Fallback to manually capture if needed
- **Payment Details**: Retrieves payment information from Razorpay

### 3. Enhanced Checkout Process (`lib/screens/checkout_screen.dart`)

**Payment Success Flow:**

1. Verify payment signature
2. Check if payment is captured
3. Manually capture if needed
4. Create order with verification details
5. Clear cart and navigate to confirmation

## Security Features

### 1. Signature Verification

```dart
final isValidSignature = PaymentVerificationService.verifyPaymentSignature(
  paymentId: response.paymentId!,
  orderId: response.orderId ?? '',
  signature: response.signature!,
);
```

### 2. Capture Status Verification

```dart
final isCaptured = await PaymentVerificationService.verifyPaymentCapture(
  response.paymentId!,
);
```

### 3. Manual Capture Fallback

```dart
if (!isCaptured) {
  await PaymentVerificationService.capturePayment(
    paymentId: response.paymentId!,
    amount: (widget.total * 100).toInt(),
    currency: 'INR',
  );
}
```

## Database Schema Updates

### Order Document Structure

```json
{
  "userId": "user_id",
  "paymentId": "razorpay_payment_id",
  "razorpayOrderId": "razorpay_order_id",
  "paymentSignature": "signature",
  "paymentVerified": true,
  "paymentCaptured": true,
  "status": "Processing",
  "createdAt": "timestamp"
}
```

## Configuration Requirements

### 1. API Keys

Ensure your production keys are set in `lib/utils/constants.dart`:

```dart
static const String razorpayKeyId = 'rzp_live_YOUR_KEY';
static const String razorpayKeySecret = 'YOUR_SECRET';
static const bool isTestMode = false;
```

### 2. Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  crypto: ^3.0.3
  http: ^1.2.0
```

### 3. Webhook Configuration (Recommended)

Set up webhooks in Razorpay dashboard:

- **Events**: `payment.captured`, `payment.failed`
- **URL**: Your server endpoint
- **Secret**: Your webhook secret

## Testing

### 1. Test Mode

```dart
static const bool isTestMode = true; // Use test keys
```

### 2. Test Cards

Use Razorpay test cards:

- **Success**: 4111 1111 1111 1111
- **Failure**: 4000 0000 0000 0002

### 3. Verification Steps

1. Make test payment
2. Check payment capture status
3. Verify order creation
4. Confirm cart clearing

## Production Checklist

- [ ] Production API keys configured
- [ ] `isTestMode` set to `false`
- [ ] Webhooks configured (optional but recommended)
- [ ] Payment verification tested
- [ ] Error handling implemented
- [ ] Order creation verified
- [ ] Cart clearing tested

## Error Handling

### Common Issues and Solutions

1. **Signature Verification Failed**

   - Check API secret key
   - Verify payment response format
   - Ensure proper signature generation

2. **Capture Failed**

   - Check payment status
   - Verify amount matches
   - Ensure proper API permissions

3. **Network Errors**
   - Implement retry logic
   - Add timeout handling
   - Provide user feedback

## Best Practices

### 1. Security

- Never expose secret keys in client code
- Always verify payment signatures
- Use HTTPS for all API calls
- Implement proper error handling

### 2. User Experience

- Show loading states during verification
- Provide clear error messages
- Handle network failures gracefully
- Confirm successful payments

### 3. Monitoring

- Log payment verification results
- Track capture success rates
- Monitor error patterns
- Set up alerts for failures

## Troubleshooting

### Payment Not Captured

1. Check if `capture: true` is set
2. Verify payment status in Razorpay dashboard
3. Check API permissions
4. Review error logs

### Signature Verification Fails

1. Verify API secret key
2. Check signature generation algorithm
3. Ensure proper payload format
4. Test with known good signatures

### Order Creation Fails

1. Check Firestore permissions
2. Verify user authentication
3. Review order data structure
4. Check network connectivity

## Support

For issues with:

- **Razorpay API**: Check Razorpay documentation
- **Flutter Implementation**: Review this guide
- **Payment Verification**: Check logs and error messages
- **Production Issues**: Contact Razorpay support
