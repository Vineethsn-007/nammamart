import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../models/grocery_item.dart';
import 'order_confirmation_screen.dart';
import '../providers/address_provider.dart';
import '../widgets/address_selection_dialog.dart';

enum PaymentMethod { razorpay, cod }

// Define a constant for the address key to ensure consistency
const String ADDRESS_PREF_KEY = 'address';

class CheckoutScreen extends StatefulWidget {
  final double total;
  final String? address;

  const CheckoutScreen({
    Key? key,
    required this.total,
    this.address,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.razorpay;
  bool _isProcessing = false;
  late Razorpay _razorpay;
  String? _paymentError;
  List<GroceryItem> _cartItems = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _deliveryAddress = '';

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _loadCartItems();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final addressProvider =
          Provider.of<AddressProvider>(context, listen: false);

      // First check if we have a passed address from the widget
      if (widget.address != null && widget.address!.isNotEmpty) {
        setState(() {
          _deliveryAddress = widget.address!;
        });

        // Also add this to the address provider if it doesn't exist
        await addressProvider.convertAndAddAddress(
          _deliveryAddress,
          setAsDefault: true,
        );

        print('Address passed from widget: $_deliveryAddress');
      }
      // Otherwise use the selected address from the provider
      else if (addressProvider.selectedAddress != null) {
        setState(() {
          _deliveryAddress = addressProvider.selectedAddress!.fullAddress;
        });
        print('Using selected address from provider: $_deliveryAddress');
      }
      // If no address is available in the provider, try to import legacy address
      else {
        await addressProvider.importLegacyAddress();

        if (addressProvider.selectedAddress != null) {
          setState(() {
            _deliveryAddress = addressProvider.selectedAddress!.fullAddress;
          });
          print('Imported legacy address: $_deliveryAddress');
        } else {
          // If still no address, try to get current location
          try {
            bool hasLocation = await _getCurrentLocationAddress();
            if (!hasLocation && mounted) {
              // If geolocation fails, prompt user to enter address
              Future.delayed(Duration(milliseconds: 300), () {
                _showAddressDialog();
              });
            }
          } catch (locationError) {
            print('Error getting current location: $locationError');
            if (mounted) {
              Future.delayed(Duration(milliseconds: 300), () {
                _showAddressDialog();
              });
            }
          }
        }
      }

      print('Final loaded address: $_deliveryAddress');
    } catch (e) {
      print('Error in _loadAddress: $e');
      // If there's an error, prompt user to enter address manually
      if (mounted) {
        Future.delayed(Duration(milliseconds: 300), () {
          _showAddressDialog();
        });
      }
    }
  }

  Future<bool> _getCurrentLocationAddress() async {
    try {
      // Check if we can access location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return false;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Create a more detailed address with null checks
        List<String> addressComponents = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressComponents.add(place.street!);
        }

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressComponents.add(place.subLocality!);
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          addressComponents.add(place.locality!);
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressComponents.add(place.administrativeArea!);
        }

        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressComponents.add(place.postalCode!);
        }

        String currentAddress = addressComponents.join(', ');

        // Update state
        setState(() {
          _deliveryAddress = currentAddress;
        });

        // Save to preferences for future use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ADDRESS_PREF_KEY, currentAddress);

        print('Successfully fetched and set current location: $currentAddress');
        return true;
      } else {
        print('Could not determine address from location');
        return false;
      }
    } catch (e) {
      print('Error in _getCurrentLocationAddress: $e');
      return false;
    }
  }

  Future<void> _loadCartItems() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final items = await cartProvider.fetchCartItems();
    setState(() {
      _cartItems = items;
    });
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Payment successful
    setState(() {
      _isProcessing = false;
    });

    // Create order in Firestore
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final subtotal = cartProvider.calculateSubtotal(_cartItems);
    final deliveryFee = cartProvider.calculateDeliveryFee(_cartItems);
    final tax = cartProvider.calculateTax(_cartItems);

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fetch phone number from Firestore
    String? phoneNumber;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      phoneNumber = userDoc.data()?['phone'] as String?;
    } catch (e) {
      phoneNumber = null;
    }

    // Convert items to a format suitable for Firestore
    final items = _cartItems.map((item) {
      return {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': cartProvider.itemQuantities[item.id] ?? 1,
        'imageUrl': item.imageUrl,
      };
    }).toList();

    // Create order document
    try {
      final orderRef = await _firestore.collection('orders').add({
        'userId': user.uid,
        'phone': phoneNumber,
        'items': items,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'tax': tax,
        'total': widget.total,
        'deliveryAddress': _deliveryAddress,
        'paymentMethod': 'Razorpay',
        'paymentId': response.paymentId,
        'status': 'Processing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear the cart
      cartProvider.clearCart();

      // Navigate to order confirmation
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              paymentMethod: _selectedPaymentMethod,
              total: widget.total,
              paymentId: response.paymentId,
              orderId: orderRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error creating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;

      // Provide more specific error messages based on error code
      if (response.code != null) {
        switch (response.code) {
          case 1000:
            _paymentError = "Payment failed: Invalid request";
            break;
          case 2000:
            _paymentError = "Network error, please check your connection";
            break;
          case 3000:
            _paymentError = "Server error, please try again later";
            break;
          case 4000:
            _paymentError = "Payment gateway error";
            break;
          default:
            _paymentError =
                response.message ?? "An error occurred during payment";
        }
      } else {
        _paymentError = response.message ?? "An error occurred during payment";
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${_paymentError}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            // Retry payment
            _processPayment();
          },
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _processPayment() async {
    if (_deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _paymentError = null;
    });

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Handle payment based on selected method
    if (_selectedPaymentMethod == PaymentMethod.razorpay) {
      setState(() {
        _isProcessing = true;
      });

      try {
        // Get theme color for Razorpay theme
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final primaryColor = themeProvider.isDarkMode
            ? themeProvider.darkPrimaryColor
            : themeProvider.lightPrimaryColor;

        // Convert Color to hex string
        final colorHex =
            '#${primaryColor.value.toRadixString(16).substring(2)}';

        // Create a description with item details
        String description = 'Payment for ';
        if (_cartItems.length == 1) {
          description += '${_cartItems[0].name}';
        } else if (_cartItems.length > 1) {
          description +=
              '${_cartItems[0].name} and ${_cartItems.length - 1} more item(s)';
        } else {
          description += 'Your order';
        }

        // Simplified options for better compatibility
        var options = {
          'key': 'rzp_test_qix9HDGt0k0hgJ',
          'amount': (widget.total * 100).toInt(),
          'name': 'NammaMart',
          'description': description,
          'prefill': {
            'contact': user.phoneNumber ?? '9876543210',
            'email': user.email ?? 'customer@example.com',
          },
          'theme': {
            'color': colorHex,
          },
        };

        // Open Razorpay checkout
        _razorpay.open(options);
      } catch (e) {
        // Handle Razorpay initialization error
        setState(() {
          _isProcessing = false;
          _paymentError = "Failed to initialize payment: ${e.toString()}";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initialization failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Cash on Delivery - proceed directly
      setState(() {
        _isProcessing = true;
      });

      // Calculate order details
      final subtotal = cartProvider.calculateSubtotal(_cartItems);
      final deliveryFee = cartProvider.calculateDeliveryFee(_cartItems);
      final tax = cartProvider.calculateTax(_cartItems);

      // Convert items to a format suitable for Firestore
      final items = _cartItems.map((item) {
        return {
          'id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': cartProvider.itemQuantities[item.id] ?? 1,
          'imageUrl': item.imageUrl,
        };
      }).toList();

      try {
        // Fetch phone number from Firestore
        String? phoneNumber;
        try {
          final userDoc =
              await _firestore.collection('users').doc(user.uid).get();
          phoneNumber = userDoc.data()?['phone'] as String?;
        } catch (e) {
          phoneNumber = null;
        }
        // Create order document
        final orderRef = await _firestore.collection('orders').add({
          'userId': user.uid,
          'phone': phoneNumber,
          'items': items,
          'subtotal': subtotal,
          'deliveryFee': deliveryFee,
          'tax': tax,
          'total': widget.total,
          'deliveryAddress': _deliveryAddress,
          'paymentMethod': 'Cash on Delivery',
          'status': 'Processing',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Clear the cart
        cartProvider.clearCart();

        // Simulate payment processing
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          // Navigate to order confirmation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderConfirmationScreen(
                paymentMethod: _selectedPaymentMethod,
                total: widget.total,
                orderId: orderRef.id,
              ),
            ),
          );
        }
      } catch (e) {
        print('Error creating order: $e');
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddressDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddressSelectionDialog(
          onAddressSelect: (address) {
            // Changed from onAddressSelected to onAddressSelect
            setState(() {
              _deliveryAddress = address.fullAddress;
            });
          },
        );
      },
    );
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
          'Checkout',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color:
                themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery address section
                  _buildSectionTitle('Delivery Address'),
                  _buildAddressCard(_deliveryAddress),
                  const SizedBox(height: 24),

                  // Payment method section
                  _buildSectionTitle('Payment Method'),
                  _buildPaymentMethodSelector(),
                  const SizedBox(height: 24),

                  // Order summary section
                  _buildSectionTitle('Order Summary'),
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAddressCard(String address) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final addressProvider = Provider.of<AddressProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    // Get the selected address from provider if available
    final selectedAddress = addressProvider.selectedAddress;
    final displayAddress = selectedAddress?.fullAddress ?? address;
    final hasMultipleAddresses = addressProvider.addresses.length > 1;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selectedAddress?.label.toLowerCase() == 'work'
                ? Icons.work
                : selectedAddress?.label.toLowerCase() == 'other'
                    ? Icons.location_on
                    : Icons.home,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      selectedAddress?.label ?? 'Deliver to:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                    if (selectedAddress?.isDefault == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayAddress.isEmpty
                      ? 'No delivery address selected'
                      : displayAddress,
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showAddressDialog,
                      child: Text(
                        displayAddress.isEmpty ? 'Add Address' : 'Change',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasMultipleAddresses && displayAddress.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Text(
                        '${addressProvider.addresses.length} addresses saved',
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Container(
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
          // Razorpay Payment Option
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.razorpay,
            groupValue: _selectedPaymentMethod,
            onChanged: (PaymentMethod? value) {
              setState(() {
                _selectedPaymentMethod = value!;
                // Clear any previous error when switching payment methods
                _paymentError = null;
              });
            },
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    'https://razorpay.com/favicon.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.payment,
                        color: primaryColor,
                        size: 24,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pay with Razorpay',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            activeColor: primaryColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),

          // Razorpay info (only shown when Razorpay is selected)
          if (_selectedPaymentMethod == PaymentMethod.razorpay)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pay securely with Credit/Debit cards, UPI, or Wallets',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPaymentIcon(
                            'Cards', Icons.credit_card, Colors.blue),
                        _buildPaymentIcon(
                            'UPI', Icons.account_balance, Colors.green),
                        _buildPaymentIcon('Wallets',
                            Icons.account_balance_wallet, Colors.orange),
                        _buildPaymentIcon(
                            'NetBanking', Icons.account_balance, Colors.purple),
                      ],
                    ),
                    if (_paymentError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Payment Error',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _paymentError!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _paymentError = null;
                                    });
                                  },
                                  child: Text(
                                    'DISMISS',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () {
                                    // Try again
                                    setState(() {
                                      _paymentError = null;
                                    });
                                    _processPayment();
                                  },
                                  child: Text(
                                    'TRY AGAIN',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // Cash on Delivery Option
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.cod,
            groupValue: _selectedPaymentMethod,
            onChanged: (PaymentMethod? value) {
              setState(() {
                _selectedPaymentMethod = value!;
                // Clear any previous error when switching payment methods
                _paymentError = null;
              });
            },
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Cash on Delivery',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            activeColor: primaryColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),

          // COD note (only shown when COD is selected)
          if (_selectedPaymentMethod == PaymentMethod.cod)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pay with cash when your order is delivered',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentIcon(String name, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '₹${widget.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.verified,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your order is eligible for free delivery',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '₹${widget.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: _deliveryAddress.isEmpty || _isProcessing
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Processing...'),
                        ],
                      )
                    : Text(
                        _selectedPaymentMethod == PaymentMethod.razorpay
                            ? 'Pay Now'
                            : 'Place Order',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
