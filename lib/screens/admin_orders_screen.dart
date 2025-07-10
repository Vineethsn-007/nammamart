import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  _AdminOrdersScreenState createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _orders = [];
  String? _errorMessage;
  
  // Filtering and sorting
  String? _filterStatus;
  String _sortBy = 'createdAt';
  bool _sortAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      Query query = FirebaseFirestore.instance.collection('orders');
      
      // Apply status filter if selected
      if (_filterStatus != null && _filterStatus!.isNotEmpty) {
        query = query.where('status', isEqualTo: _filterStatus);
      }
      
      // Apply sorting
      query = query.orderBy(_sortBy, descending: !_sortAscending);
      
      final snapshot = await query.get();
      
      setState(() {
        _orders = snapshot.docs;
        _isLoading = false;
      });
      
      // Apply search filter in memory (Firestore doesn't support text search)
      if (_searchQuery.isNotEmpty) {
        _applySearchFilter();
      }
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }
  
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _loadOrders();
      return;
    }
    
    final query = _searchQuery.toLowerCase();
    setState(() {
      _orders = _orders.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Search in order ID
        if (doc.id.toLowerCase().contains(query)) {
          return true;
        }
        
        // Search in user ID or email
        if ((data['userId'] as String?)?.toLowerCase().contains(query) ?? false) {
          return true;
        }
        
        // Search in delivery address
        if ((data['deliveryAddress'] as String?)?.toLowerCase().contains(query) ?? false) {
          return true;
        }
        
        // Search in items
        final items = data['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          if ((item['name'] as String?)?.toLowerCase().contains(query) ?? false) {
            return true;
          }
        }
        
        return false;
      }).toList();
    });
  }
  
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh orders list
      _loadOrders();
    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showOrderDetails(BuildContext context, Map<String, dynamic> orderData, String orderId) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    
    final items = orderData['items'] as List<dynamic>? ?? [];
    final total = orderData['total'] as num? ?? 0.0;
    final address = orderData['deliveryAddress'] as String? ?? 'No address provided';
    final paymentMethod = orderData['paymentMethod'] as String? ?? 'Not specified';
    final paymentId = orderData['paymentId'] as String?;
    final subtotal = orderData['subtotal'] as num? ?? 0.0;
    final deliveryFee = orderData['deliveryFee'] as num? ?? 0.0;
    final tax = orderData['tax'] as num? ?? 0.0;
    final status = orderData['status'] as String? ?? 'Processing';
    final userId = orderData['userId'] as String? ?? 'Unknown';
    
    // Format timestamps
    String createdAt = 'Unknown';
    if (orderData['createdAt'] != null) {
      try {
        final timestamp = orderData['createdAt'] as Timestamp;
        createdAt = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
      } catch (e) {
        print('Error formatting timestamp: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt, color: primaryColor),
            const SizedBox(width: 8),
            Text('Order Details', style: TextStyle(color: primaryColor)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order ID and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${orderId.substring(0, min(orderId.length, 8)).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status, themeProvider.isDarkMode),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _getStatusTextColor(status, themeProvider.isDarkMode),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Created At and User ID
                Text(
                  'Created: $createdAt',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'User ID: $userId',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Items Section
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // Items List
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                        _buildOrderItemTile(items[i], themeProvider.isDarkMode),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Order Summary
                const Text('Order Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Subtotal:', '₹${subtotal.toStringAsFixed(2)}', false),
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Delivery Fee:',
                        deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(2)}' : 'FREE',
                        false,
                        valueColor: deliveryFee > 0 ? null : Colors.green,
                      ),
                      const SizedBox(height: 4),
                      _buildSummaryRow('Tax:', '₹${tax.toStringAsFixed(2)}', false),
                      Divider(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                      _buildSummaryRow('Total:', '₹${total.toStringAsFixed(2)}', true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Delivery Address
                const Text('Delivery Address:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(address),
                ),
                
                const SizedBox(height: 16),
                
                // Payment Information
                const Text('Payment Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Method: $paymentMethod'),
                      if (paymentId != null) ...[
                        const SizedBox(height: 4),
                        Text('Payment ID: $paymentId'),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Update Status Section
                const Text('Update Order Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusButton('Processing', status, primaryColor),
                    _buildStatusButton('Shipped', status, primaryColor),
                    _buildStatusButton('Delivered', status, primaryColor),
                    _buildStatusButton('Cancelled', status, primaryColor),
                  ],
                ),
              ],
            ),
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
  
  Widget _buildOrderItemTile(Map<String, dynamic> item, bool isDarkMode) {
    final name = item['name'] as String? ?? 'Unknown item';
    final quantity = item['quantity'] as int? ?? 1;
    final price = item['price'] as num? ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Item image if available
          if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                image: DecorationImage(
                  image: NetworkImage(item['imageUrl']),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Quantity: $quantity × ₹${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Item total
          Text(
            '₹${(price * quantity).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value, bool isTotal, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusButton(String status, String currentStatus, Color primaryColor) {
    final isSelected = status == currentStatus;
    
    return ElevatedButton(
      onPressed: isSelected
          ? null
          : () {
              Navigator.pop(context);
              _showStatusConfirmation(context, status);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? primaryColor : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: isSelected ? 0 : 1,
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  void _showStatusConfirmation(BuildContext context, String newStatus) {
    final selectedOrder = _orders.isNotEmpty ? _orders[0] : null;
    if (selectedOrder == null) return;
    
    final orderId = selectedOrder.id;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status'),
        content: Text('Are you sure you want to update this order to "$newStatus"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(orderId, newStatus);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status) {
      case 'Delivered':
        return isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100;
      case 'Processing':
        return isDarkMode ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade100;
      case 'Shipped':
        return isDarkMode ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade100;
      case 'Cancelled':
        return isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100;
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
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    final backgroundColor = themeProvider.isDarkMode
        ? themeProvider.darkBackgroundColor
        : themeProvider.lightBackgroundColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'Manage Orders',
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
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _loadOrders();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applySearchFilter();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Filter and sort controls
                Row(
                  children: [
                    // Status filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterStatus,
                        decoration: InputDecoration(
                          labelText: 'Filter by Status',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Statuses'),
                          ),
                          ...['Processing', 'Shipped', 'Delivered', 'Cancelled'].map((status) {
                            return DropdownMenuItem<String?>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterStatus = value;
                          });
                          _loadOrders();
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Sort dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'createdAt',
                            child: Text('Date'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'total',
                            child: Text('Amount'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'status',
                            child: Text('Status'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                          });
                          _loadOrders();
                        },
                      ),
                    ),
                    
                    // Sort direction button
                    IconButton(
                      icon: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                        _loadOrders();
                      },
                      tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      style: IconButton.styleFrom(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Active filters
                if (_filterStatus != null || _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_filterStatus != null)
                          Chip(
                            label: Text('Status: $_filterStatus'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _filterStatus = null;
                              });
                              _loadOrders();
                            },
                            backgroundColor: primaryColor.withOpacity(0.1),
                            labelStyle: TextStyle(color: primaryColor),
                          ),
                        
                        if (_searchQuery.isNotEmpty)
                          Chip(
                            label: Text('Search: $_searchQuery'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _loadOrders();
                            },
                            backgroundColor: primaryColor.withOpacity(0.1),
                            labelStyle: TextStyle(color: primaryColor),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Orders list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
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
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
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
                              onPressed: _loadOrders,
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
                      )
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty || _filterStatus != null
                                      ? 'No orders match your filters'
                                      : 'No orders found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_searchQuery.isNotEmpty || _filterStatus != null)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _filterStatus = null;
                                      });
                                      _loadOrders();
                                    },
                                    icon: const Icon(Icons.filter_alt_off),
                                    label: const Text('Clear Filters'),
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
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final orderDoc = _orders[index];
                              final orderData = orderDoc.data() as Map<String, dynamic>;
                              final orderId = orderDoc.id;
                              
                              final orderDate = orderData['createdAt'] as Timestamp?;
                              final orderStatus = orderData['status'] as String? ?? 'Processing';
                              final orderItems = orderData['items'] as List<dynamic>? ?? [];
                              final orderTotal = orderData['total'] as num? ?? 0.0;
                              final userId = orderData['userId'] as String? ?? 'Unknown';
                              
                              final formattedDate = orderDate != null
                                  ? DateFormat('MMM dd, yyyy').format(orderDate.toDate())
                                  : 'Unknown date';
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _showOrderDetails(context, orderData, orderId),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Order header
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Order #${orderId.substring(0, min(orderId.length, 8)).toUpperCase()}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
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
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(orderStatus, themeProvider.isDarkMode),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                orderStatus,
                                                style: TextStyle(
                                                  color: _getStatusTextColor(orderStatus, themeProvider.isDarkMode),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // User ID
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'User: $userId',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 8),
                                        
                                        // Items summary
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 16,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${orderItems.length} ${orderItems.length == 1 ? 'item' : 'items'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Divider
                                        Divider(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Order total and actions
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Total Amount',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '₹${orderTotal.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                // View details button
                                                OutlinedButton.icon(
                                                  onPressed: () => _showOrderDetails(context, orderData, orderId),
                                                  icon: Icon(Icons.visibility_outlined, size: 16, color: primaryColor),
                                                  label: Text(
                                                    'Details',
                                                    style: TextStyle(color: primaryColor),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: primaryColor),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                                
                                                const SizedBox(width: 8),
                                                
                                                // Update status button
                                                PopupMenuButton<String>(
                                                  onSelected: (status) {
                                                    _showStatusConfirmation(context, status);
                                                  },
                                                  itemBuilder: (context) => [
                                                    'Processing',
                                                    'Shipped',
                                                    'Delivered',
                                                    'Cancelled',
                                                  ].map((status) {
                                                    return PopupMenuItem<String>(
                                                      value: status,
                                                      enabled: status != orderStatus,
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 12,
                                                            height: 12,
                                                            decoration: BoxDecoration(
                                                              color: _getStatusColor(status, themeProvider.isDarkMode),
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(status),
                                                          if (status == orderStatus)
                                                            const Spacer()
                                                          else
                                                            const SizedBox.shrink(),
                                                          if (status == orderStatus)
                                                            const Icon(Icons.check, size: 16)
                                                          else
                                                            const SizedBox.shrink(),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                  child: ElevatedButton.icon(
                                                    onPressed: null,
                                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                                    label: const Text('Status'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: primaryColor,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                            )],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
