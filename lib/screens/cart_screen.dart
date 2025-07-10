import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/grocery_item.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/address_provider.dart'; // Add this import
import '../widgets/address_selection_dialog.dart'; // Add this import
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Address is now handled by AddressProvider
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    // ignore: unused_local_variable
    final addressProvider = Provider.of<AddressProvider>(context); // Add this
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
          'My Cart',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (cartProvider.cartItemIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
              onPressed: () {
                // Clear cart functionality
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to clear your cart?'),
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade400 
                                : Colors.grey.shade700
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          cartProvider.clearCart();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Clear',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cartProvider.cartItemIds.isEmpty
          ? _buildEmptyCart()
          : FutureBuilder<List<GroceryItem>>(
              future: cartProvider.fetchCartItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading cart items',
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  );
                }
                
                final cartItems = snapshot.data ?? [];
                
                if (cartItems.isEmpty) {
                  return _buildEmptyCart();
                }
                
                final subtotal = cartProvider.calculateSubtotal(cartItems);
                final deliveryFee = cartProvider.calculateDeliveryFee(subtotal);
                final tax = cartProvider.calculateTax(subtotal);
                final total = cartProvider.calculateTotal(subtotal);
                
                return Column(
                  children: [
                    // Add delivery address card - NEW!
                    _buildDeliveryAddressCard(),
                    
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final quantity = cartProvider.itemQuantities[item.id] ?? 1;
                          
                          return _buildCartItem(item, quantity, cartProvider);
                        },
                      ),
                    ),
                    _buildOrderSummary(subtotal, deliveryFee, tax, total),
                  ],
                );
              },
            ),
    );
  }
  
  // NEW: Build delivery address card
  Widget _buildDeliveryAddressCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final addressProvider = Provider.of<AddressProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
        
    final selectedAddress = addressProvider.selectedAddress;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: themeProvider.isDarkMode 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Show address selection dialog
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => AddressSelectionDialog(
                      onAddressSelect: (address) {
                        addressProvider.selectAddress(address.id);
                      },
                    ),
                  );
                },
                child: Text(
                  selectedAddress == null ? 'Add Address' : 'Change',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          if (selectedAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 30), // Align with the text above
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedAddress.label,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 30), // Align with the text above
                Expanded(
                  child: Text(
                    selectedAddress.fullAddress,
                    style: TextStyle(
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade300 
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 30.0),
              child: Text(
                'No delivery address selected',
                style: TextStyle(
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyCart() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
        
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? themeProvider.darkSurfaceColor 
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode 
                  ? Colors.white 
                  : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add items to your cart to start shopping',
              style: TextStyle(
                fontSize: 16,
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade400 
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Navigate back to home/products
             Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Start Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCartItem(GroceryItem item, int quantity, CartProvider cartProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
      
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode 
              ? Colors.red.shade900.withOpacity(0.3) 
              : Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: themeProvider.isDarkMode 
              ? Colors.red.shade300 
              : Colors.red.shade700,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        cartProvider.removeFromCart(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} removed from cart'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                cartProvider.addToCart(item.id);
                cartProvider.updateQuantity(item.id, quantity);
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
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
        child: Row(
          children: [
            // Product image with improved styling
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(
                width: 110,
                height: 110,
                color: primaryColor.withOpacity(0.05),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.image_not_supported_outlined,
                        color: primaryColor,
                        size: 40,
                      ),
                    )
                  : Icon(
                      Icons.shopping_bag_outlined,
                      color: primaryColor,
                      size: 40,
                    ),
              ),
            ),
            
            // Product details with improved layout
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Favorite button
                        IconButton(
                          icon: Icon(
                            Icons.favorite_border,
                            size: 20,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () {
                            // Add to wishlist functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to wishlist'),
                                backgroundColor: primaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          constraints: BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.unit,
                      style: TextStyle(
                        color: themeProvider.isDarkMode 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.discountPercentage > 0)
                              Row(
                                children: [
                                  Text(
                                    '₹${item.originalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: themeProvider.isDarkMode 
                                          ? Colors.grey.shade500 
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.discountPercentage.toStringAsFixed(0)}% OFF',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Text(
                              '₹${item.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        // Quantity controls with improved styling
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => cartProvider.updateQuantity(item.id, quantity - 1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(7),
                                  bottomLeft: Radius.circular(7),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      bottomLeft: Radius.circular(7),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  quantity.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => cartProvider.updateQuantity(item.id, quantity + 1),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(7),
                                  bottomRight: Radius.circular(7),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(7),
                                      bottomRight: Radius.circular(7),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ₹${(item.price * quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOrderSummary(
    double subtotal,
    double deliveryFee,
    double tax,
    double total,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    final addressProvider = Provider.of<AddressProvider>(context); // Add this
      
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode 
                      ? Colors.white 
                      : Colors.grey.shade800,
                ),
              ),
              // Add a coupon button
              TextButton.icon(
                onPressed: () {
                  // Show coupon dialog
                  _showCouponDialog();
                },
                icon: Icon(
                  Icons.local_offer_outlined,
                  size: 16,
                  color: primaryColor,
                ),
                label: Text(
                  'Apply Coupon',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Enhanced summary items with card background
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? Colors.grey.shade800.withOpacity(0.5) 
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade700 
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        color: themeProvider.isDarkMode 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '₹${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Fee',
                      style: TextStyle(
                        color: themeProvider.isDarkMode 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(2)}' : 'FREE',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: deliveryFee > 0 
                            ? (themeProvider.isDarkMode ? Colors.white : Colors.black87)
                            : Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tax (5%)',
                      style: TextStyle(
                        color: themeProvider.isDarkMode 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '₹${tax.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade700 
                        : Colors.grey.shade300
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Enhanced checkout button
          ElevatedButton(
            onPressed: () {
              // Check if address is selected before proceeding
              if (addressProvider.selectedAddress == null) {
                // Show address selection dialog if no address is selected
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => AddressSelectionDialog(
                    onAddressSelect: (address) {
                      addressProvider.selectAddress(address.id);
                    },
                  ),
                );
                
                // Show a message to the user
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select a delivery address'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }
              
              // Navigate to checkout screen with payment options
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    total: total,
                    address: addressProvider.selectedAddress?.fullAddress,
                  ),
                ),
              );
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_checkout),
                const SizedBox(width: 8),
                const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: themeProvider.isDarkMode 
                  ? Colors.grey.shade400 
                  : Colors.grey.shade700,
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  // Add a method to show coupon dialog
  void _showCouponDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    final TextEditingController _couponController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apply Coupon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _couponController,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  prefixIcon: Icon(Icons.local_offer, color: primaryColor),
                  suffixIcon: TextButton(
                    onPressed: () {
                      // Apply coupon logic
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Coupon applied successfully!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'APPLY',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              Text(
                'Available Coupons',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              // Sample coupons
              _buildCouponItem(
                'WELCOME20', 
                '20% off on your first order',
                'Min order: ₹500',
                primaryColor
              ),
              _buildCouponItem(
                'FREESHIP', 
                'Free shipping on all orders',
                'Valid until 30 Apr 2025',
                Colors.orange.shade700
              ),
              _buildCouponItem(
                'SAVE10', 
                '₹10 off on orders above ₹100',
                'Valid for all users',
                Colors.green.shade700
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build coupon items
  Widget _buildCouponItem(String code, String description, String condition, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  condition,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Copy to clipboard
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Coupon code copied!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text('APPLY'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
