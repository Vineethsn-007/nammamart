// screens/order_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'checkout_screen.dart';
import 'dart:math' as Math;

class OrderConfirmationScreen extends StatelessWidget {
  final PaymentMethod paymentMethod;
  final double total;
  final String? paymentId;
  final String orderId;

  const OrderConfirmationScreen({
    Key? key,
    required this.paymentMethod,
    required this.total,
    this.paymentId, 
    required this.orderId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    final backgroundColor = themeProvider.isDarkMode
        ? themeProvider.darkBackgroundColor
        : themeProvider.lightBackgroundColor;

    // Use the provided orderId instead of generating a random one
    final displayOrderId = 'ORD-${orderId.substring(0, Math.min(8, orderId.length))}';
    final estimatedDelivery = DateTime.now().add(const Duration(days: 3));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'Order Confirmation',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Success icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Success message
                  Text(
                    'Order Placed Successfully!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your order has been confirmed and will be delivered soon.',
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Order details
                  _buildOrderDetailCard(
                    context,
                    orderId: displayOrderId,
                    paymentMethod: paymentMethod,
                    total: total,
                    estimatedDelivery: estimatedDelivery,
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment instructions for COD
                  if (paymentMethod == PaymentMethod.cod)
                    _buildCodInstructions(context),
                  
                  // Payment instructions for Razorpay
                  if (paymentMethod == PaymentMethod.razorpay)
                    _buildRazorpayInstructions(context),
                ],
              ),
            ),
          ),
          
          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: themeProvider.isDarkMode
                      ? Colors.black26
                      : Colors.grey.shade300,
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Track order functionality
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Track Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Clear cart and navigate back to home
                        // TODO: Add proper cart clearing logic using CartProvider
                        // For now, we'll just navigate back to the first screen
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Continue Shopping',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailCard(
    BuildContext context, {
    required String orderId,
    required PaymentMethod paymentMethod,
    required double total,
    required DateTime estimatedDelivery,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode
                ? Colors.black26
                : Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOrderDetailRow(
            context,
            title: 'Order ID',
            value: orderId,
          ),
          const Divider(height: 24),
          _buildOrderDetailRow(
            context,
            title: 'Payment Method',
            value: paymentMethod == PaymentMethod.razorpay
                ? 'Razorpay'
                : 'Cash on Delivery',
          ),
          const Divider(height: 24),
          _buildOrderDetailRow(
            context,
            title: 'Amount Paid',
            value: '₹${total.toStringAsFixed(2)}',
          ),
          const Divider(height: 24),
          _buildOrderDetailRow(
            context,
            title: 'Estimated Delivery',
            value: '${estimatedDelivery.day}/${estimatedDelivery.month}/${estimatedDelivery.year}',
          ),
          if (paymentId != null) ...[
            const Divider(height: 24),
            _buildOrderDetailRow(
              context,
              title: 'Payment ID',
              value: paymentId!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderDetailRow(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.isDarkMode
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCodInstructions(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: themeProvider.isDarkMode
                    ? Colors.amber.shade300
                    : Colors.amber.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Cash on Delivery Instructions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            context,
            icon: Icons.payments_outlined,
            text: 'Please keep exact change ready for a smooth delivery experience.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            context,
            icon: Icons.verified_user_outlined,
            text: 'Our delivery partner will verify your order before handing it over.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            context,
            icon: Icons.receipt_long_outlined,
            text: 'You will receive a payment receipt after successful delivery.',
          ),
        ],
      ),
    );
  }

  Widget _buildRazorpayInstructions(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: themeProvider.isDarkMode
                    ? Colors.green.shade300
                    : Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Razorpay Payment Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            context,
            icon: Icons.check_circle_outline,
            text: 'Your payment has been processed successfully.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            context,
            icon: Icons.receipt_long_outlined,
            text: 'A payment receipt has been sent to your registered email.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            context,
            icon: Icons.security_outlined,
            text: 'Your payment is secure and protected by Razorpay.',
          ),
          if (paymentId != null) ...[
            const SizedBox(height: 8),
            _buildInstructionItem(
              context,
              icon: Icons.confirmation_number_outlined,
              text: 'Payment ID: $paymentId',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: themeProvider.isDarkMode
              ? Colors.grey.shade400
              : Colors.grey.shade700,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
