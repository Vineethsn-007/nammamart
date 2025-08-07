// lib/screens/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import 'home_screen.dart';
// ignore: unused_import
import '../widgets/network_aware_widget.dart';
import 'dart:async';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _orders = [];
  String? _errorMessage;
  bool _isMounted = true;
  bool _hasInternetConnection = true;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure the widget is fully mounted
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _checkConnectivityAndLoadOrders();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _checkConnectivityAndLoadOrders() async {
    try {
      // Try to make a simple request to check connectivity
      await FirebaseFirestore.instance
          .collection('connectivity_check')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      setState(() {
        _hasInternetConnection = true;
      });
      _loadOrders();
    } catch (e) {
      print('Connectivity check failed: $e');
      if (!mounted) return;
      setState(() {
        _hasInternetConnection = false;
        _isLoading = false;
        _errorMessage =
            'No internet connection. Please check your network settings and try again.';
      });
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print('Fetching orders for user: ${currentUser.uid}');

      // IMPORTANT: Modified query to avoid the need for a composite index
      // Only using one orderBy clause instead of two
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${snapshot.docs.length} orders for user ${currentUser.uid}');

      // Debug: Print the first order if available
      if (snapshot.docs.isNotEmpty) {
        print('First order data: ${snapshot.docs.first.data()}');
      }

      if (!mounted) return;
      setState(() {
        _orders = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');

      String errorMsg = 'Failed to load orders. Please try again.';

      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        if (e.code == 'permission-denied') {
          errorMsg = 'You don\'t have permission to access orders.';
        } else if (e.code == 'unavailable') {
          errorMsg =
              'Service is currently unavailable. Please check your internet connection.';
        } else if (e.code == 'failed-precondition') {
          // This is the error we're seeing in the logs - need to create an index
          errorMsg =
              'The database is not properly configured. Please contact support.';

          // For development purposes, you can uncomment this to see the index creation URL
          // errorMsg = 'Index required. ${e.message}';
        }
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    final backgroundColor = themeProvider.isDarkMode
        ? themeProvider.darkBackgroundColor
        : themeProvider.lightBackgroundColor;

    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'Order History',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              _checkConnectivityAndLoadOrders();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: !_hasInternetConnection
            ? _buildNoInternetView(context, primaryColor)
            : currentUser == null
                ? _buildNotLoggedInView(context, primaryColor)
                : _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorView(context, primaryColor)
                        : _orders.isEmpty
                            ? _buildEmptyOrdersView(context, primaryColor)
                            : _buildOrdersList(context),
      ),
    );
  }

  Widget _buildNoInternetView(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _checkConnectivityAndLoadOrders();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    // Debug print to verify we're reaching this method
    print('Building orders list with ${_orders.length} orders');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final orderData = _orders[index].data() as Map<String, dynamic>;
          final orderId = _orders[index].id;

          // Debug print to check order data
          print('Order $index data: $orderData');

          final orderDate = orderData['createdAt'] as Timestamp?;
          final orderStatus = orderData['status'] as String? ?? 'Processing';
          final orderItems = orderData['items'] as List<dynamic>? ?? [];
          final orderTotal = orderData['total'] as num? ?? 0.0;

          final formattedDate = orderDate != null
              ? DateFormat('MMM dd, yyyy').format(orderDate.toDate())
              : 'Unknown date';

          final isDelivered = orderStatus == 'Delivered';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${orderId.substring(0, min(orderId.length, 8)).toUpperCase()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                              orderStatus, themeProvider.isDarkMode),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          orderStatus,
                          style: TextStyle(
                            color: _getStatusTextColor(
                                orderStatus, themeProvider.isDarkMode),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${orderItems.length} items',
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '₹${orderTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (orderData.containsKey('paymentId') &&
                    orderData['paymentId'] != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payment,
                          size: 16,
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment ID: ${(orderData['paymentId'] as String).substring(0, min((orderData['paymentId'] as String).length, 12))}...',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _showOrderDetails(context, orderData, orderId);
                        },
                        icon: Icon(Icons.visibility,
                            size: 18, color: primaryColor),
                        label: Text('View Details',
                            style: TextStyle(color: primaryColor)),
                      ),
                      if (isDelivered)
                        TextButton.icon(
                          onPressed: () {
                            _reorder(context, orderItems);
                          },
                          icon: Icon(Icons.refresh,
                              size: 18, color: primaryColor),
                          label: Text('Reorder',
                              style: TextStyle(color: primaryColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, Color primaryColor) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Please try again later',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _checkConnectivityAndLoadOrders();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status) {
      case 'Delivered':
        return isDarkMode
            ? Colors.green.shade900.withOpacity(0.3)
            : Colors.green.shade100;
      case 'Processing':
        return isDarkMode
            ? Colors.blue.shade900.withOpacity(0.3)
            : Colors.blue.shade100;
      case 'Shipped':
        return isDarkMode
            ? Colors.orange.shade900.withOpacity(0.3)
            : Colors.orange.shade100;
      case 'Cancelled':
        return isDarkMode
            ? Colors.red.shade900.withOpacity(0.3)
            : Colors.red.shade100;
      default:
        return isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status, bool isDarkMode) {
    switch (status) {
      case 'Delivered':
        return isDarkMode ? Colors.green.shade300 : Colors.green.shade800;
      case 'Processing':
        return isDarkMode ? Colors.blue.shade300 : Colors.blue.shade800;
      case 'Shipped':
        return isDarkMode ? Colors.orange.shade300 : Colors.orange.shade800;
      case 'Cancelled':
        return isDarkMode ? Colors.red.shade300 : Colors.red.shade800;
      default:
        return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800;
    }
  }

  void _showOrderDetails(
      BuildContext context, Map<String, dynamic> orderData, String orderId) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    final items = orderData['items'] as List<dynamic>? ?? [];
    final total = orderData['total'] as num? ?? 0.0;
    final address =
        orderData['deliveryAddress'] as String? ?? 'No address provided';
    final paymentMethod =
        orderData['paymentMethod'] as String? ?? 'Not specified';
    final paymentId = orderData['paymentId'] as String?;
    final subtotal = orderData['subtotal'] as num? ?? 0.0;
    final deliveryFee = orderData['deliveryFee'] as num? ?? 0.0;
    final tax = orderData['tax'] as num? ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details', style: TextStyle(color: primaryColor)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order #${orderId.substring(0, min(orderId.length, 8)).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Items:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) {
                final name = item['name'] as String? ?? 'Unknown item';
                final quantity = item['quantity'] as int? ?? 1;
                final price = item['price'] as num? ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('$name x $quantity'),
                      ),
                      Text('₹${(price * quantity).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }).toList(),
              Divider(color: Colors.grey.shade300),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('₹${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(deliveryFee > 0
                      ? '₹${deliveryFee.toStringAsFixed(2)}'
                      : 'FREE'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('₹${tax.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 4),
              Divider(color: Colors.grey.shade300),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Delivery Address:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(address),
              const SizedBox(height: 16),
              const Text('Payment Method:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(paymentMethod),
              if (paymentId != null) ...[
                const SizedBox(height: 16),
                const Text('Payment ID:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(paymentId),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _reorder(BuildContext context, List<dynamic> items) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    cartProvider.clearCart();

    for (var item in items) {
      final productId = item['id'] as String? ?? '';
      final quantity = item['quantity'] as int? ?? 1;

      if (productId.isNotEmpty) {
        cartProvider.addToCart(productId);
        cartProvider.updateQuantity(productId, quantity);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Items added to cart'),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Widget _buildEmptyOrdersView(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your order history will appear here once you make a purchase',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to home screen and clear the navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInView(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in to view orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Please sign in to view your order history',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Navigate to home screen and clear the navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
                (route) => false,
              );
            },
            child: Text(
              'Continue Shopping',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }
}
