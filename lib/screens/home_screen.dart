// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:namma_store/providers/cart_provider.dart';
import 'package:namma_store/screens/admin_orders_screen.dart';
import 'package:provider/provider.dart';
import '../models/grocery_item.dart';
import '../providers/theme_provider.dart';
import 'admin_product_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; 
import 'package:google_fonts/google_fonts.dart';
import '../providers/address_provider.dart';
import '../widgets/address_selection_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Add AutomaticKeepAliveClientMixin to prevent unnecessary rebuilds
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;

  // Firestore references
  final categoriesRef = FirebaseFirestore.instance.collection('categories');
  final productsRef = FirebaseFirestore.instance.collection('products');

  // Search functionality
  late TextEditingController _searchController;
  List<GroceryItem> _searchResults = [];
  bool _isSearching = false;

  // Selected category for viewing items
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  List<GroceryItem> _categoryProducts = [];
  bool _isLoadingCategoryProducts = false;

  // Location variables
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  String _currentAddress = '';
  bool _locationPermissionGranted = false;

  // Stream subscriptions to properly manage and dispose
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // Initialize data without causing rebuilds
    _initializeFirebaseData();

    // Add a post-frame callback to start auto-scroll after the first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Auto-scroll removed as requested
        _checkLocationPermission();
      }
    });
  }

  Future<void> _saveLocationToPrefs() async {
    if (_currentPosition != null && _currentAddress.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('latitude', _currentPosition!.latitude);
        await prefs.setDouble('longitude', _currentPosition!.longitude);
        await prefs.setString('address', _currentAddress);
        print('Location saved to prefs: $_currentAddress');
      } catch (e) {
        print('Error saving location to prefs: $e');
      }
    }
  }

  Future<bool> _loadLocationFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latitude = prefs.getDouble('latitude');
      final longitude = prefs.getDouble('longitude');
      final address = prefs.getString('address');

      if (latitude != null && longitude != null && address != null) {
        if (!mounted) return true;

        setState(() {
          _currentPosition = Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          _currentAddress = address;
          _isLoadingLocation = false;
        });
        return true;
      }
    } catch (e) {
      print('Error loading location from prefs: $e');
    }
    return false;
  }

  // Make sure to properly dispose all resources
  @override
  void dispose() {
    _searchController.dispose();

    // Cancel all stream subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  // Initialize Firebase with dummy data if collections are empty
  Future<void> _initializeFirebaseData() async {
    try {
      // Check if categories collection is empty
      final categoriesSnapshot = await categoriesRef.limit(1).get();
      if (categoriesSnapshot.docs.isEmpty) {
        // Add dummy categories
        for (var category in dummyCategories) {
          await categoriesRef.doc(category['id']).set({
            'name': category['name'],
            'iconCode': category['iconCode'],
            'color': category['color'],
            'imageUrl': category['imageUrl'],
          });
        }
      }
    } catch (e) {
      print('Error initializing Firebase data: $e');
    }
  }

  // Check location permission
  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionGranted = false;
        });

        // Show dialog to enable location services
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              final primaryColor = themeProvider.isDarkMode
                  ? themeProvider.darkPrimaryColor
                  : themeProvider.lightPrimaryColor;
              return AlertDialog(
                title: const Text('Location Services Disabled'),
                content: const Text(
                    'Please enable location services to use automatic location detection.'),
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Geolocator.openLocationSettings();
                    },
                    child: Text('Open Settings', style: TextStyle(color: primaryColor)),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Check location permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionGranted = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionGranted = false;
        });
        // Show dialog to open app settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              final primaryColor = themeProvider.isDarkMode
                  ? themeProvider.darkPrimaryColor
                  : themeProvider.lightPrimaryColor;
              return AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text(
                    'Location permission is permanently denied. Please enable it in app settings.'),
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Geolocator.openAppSettings();
                    },
                    child: Text('Open Settings', style: TextStyle(color: primaryColor)),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Permissions granted, update state and get location
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
      });

      await _getCurrentLocation();
    } catch (e) {
      print('Error checking location permission: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationPermissionGranted = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error with location services: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // Get current location - FIXED to improve reliability
 Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // FIXED: Increased timeout and added forceAndroidLocationManager for better reliability
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30), // Increased from 15 to 30 seconds
        forceAndroidLocationManager: true, // Added for better reliability on some Android devices
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });

      // Get address from coordinates
      await _getAddressFromLatLng();
    } catch (e) {
      print('Error getting position: $e');
      
      // FIXED: Try with lower accuracy if high accuracy fails
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );

        if (!mounted) return;

        setState(() {
          _currentPosition = position;
        });

        // Get address from coordinates
        await _getAddressFromLatLng();
        return;
      } catch (fallbackError) {
        print('Fallback location error: $fallbackError');
        
        if (!mounted) return;

        setState(() {
          _isLoadingLocation = false;
        });

        // Show address selection dialog on error
        if (mounted) {
          _showAddressSelectionDialog();
        }
      }
    }
  }

  Future<void> _getAddressFromLatLng() async {
    if (!mounted || _currentPosition == null) return;

    try {
      setState(() {
        _isLoadingLocation = true;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (!mounted) return;

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
        
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressComponents.add(place.administrativeArea!);
        }
        
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressComponents.add(place.postalCode!);
        }
        
      String fullAddress = addressComponents.join(', ');
      
      setState(() {
        _currentAddress = fullAddress;
        _isLoadingLocation = false;
      });

      // Save to the address provider
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      await addressProvider.convertAndAddAddress(
        fullAddress,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        setAsDefault: true,
      );
      
      print('Address set to: $_currentAddress');
    } else {
      setState(() {
        _currentAddress = 'Address not found';
        _isLoadingLocation = false;
      });
      
      // Prompt user to enter address manually if geocoding fails
      _showAddressSelectionDialog();
    }
  } catch (e) {
    print('Error getting address: $e');
    if (!mounted) return;

    setState(() {
      _currentAddress = 'Error getting address';
      _isLoadingLocation = false;
    });
    
    // Prompt user to enter address manually if geocoding fails
    _showAddressSelectionDialog();
  }
}

// Build location widget
Widget _buildLocationWidget() {
  final themeProvider = Provider.of<ThemeProvider>(context);
  final addressProvider = Provider.of<AddressProvider>(context);
  final primaryColor = themeProvider.isDarkMode
      ? themeProvider.darkPrimaryColor
      : themeProvider.lightPrimaryColor;

  // Import legacy address if needed
  if (addressProvider.addresses.isEmpty && _currentAddress.isNotEmpty) {
    // This will run only once when needed
    Future.delayed(Duration.zero, () {
      addressProvider.convertAndAddAddress(
        _currentAddress,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        setAsDefault: true,
      );
    });
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
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
        Icon(
          Icons.location_on,
          color: primaryColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _isLoadingLocation
              ? Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Getting your location...',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : !_locationPermissionGranted
                  ? GestureDetector(
                      onTap: _checkLocationPermission,
                      child: Row(
                        children: [
                          Text(
                            'Enable location services',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _showAddressSelectionDialog,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              addressProvider.selectedAddress != null
                                  ? 'Deliver to: ${addressProvider.selectedAddress!.fullAddress}'
                                  : _currentAddress.isEmpty
                                      ? 'Select your location'
                                      : 'Deliver to: $_currentAddress',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: addressProvider.selectedAddress != null || !_currentAddress.isEmpty
                                    ? themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87
                                    : themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    ),
  );
}

// Replace the _showLocationOptions method with this new method
void _showAddressSelectionDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return AddressSelectionDialog(
        onAddressSelect: (address) {
          setState(() {
            _currentAddress = address.fullAddress;
          });
        },
      );
    },
  );
}

  void _showLocationOptions() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

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
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.isDarkMode
                        ? Colors.black26
                        : Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Use current location option
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: primaryColor,
                      ),
                    ),
                    title: Text(
                      'Use current location',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Get products delivered to your current location',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _getCurrentLocation();
                    },
                  ),

                  const SizedBox(height: 10),

                  // Enter manually option
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_location_alt,
                        color: primaryColor,
                      ),
                    ),
                    title: Text(
                      'Enter location manually',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Type your address for delivery',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showManualLocationEntry();
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ));
      },
    );
  }

  // Add this method to show manual location entry dialog
  void _showManualLocationEntry() {
  _showAddressSelectionDialog();
}

  // Search products functionality - FIXED to make search functional
  Future<void> _searchProducts(String query) async {
    if (!mounted) return;

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search by name (case-insensitive)
      final querySnapshot = await productsRef
          .where('nameSearch', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('nameSearch',
              isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
          .get();

      if (!mounted) return;

      final products = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return GroceryItem(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Product',
          price: (data['price'] ?? 0).toDouble(),
          originalPrice:
              (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
          discountPercentage: (data['discountPercentage'] ?? 0).toDouble(),
          unit: data['unit'] ?? 'item',
          imageUrl: data['imageUrl'],
          isPopular: data['isPopular'] ?? false,
          isSpecialOffer: data['isSpecialOffer'] ?? false,
          icon: IconData(
            data['iconCode'] ?? 0xe25e,
            fontFamily: 'MaterialIcons',
          ),
          categoryId: data['categoryId'] ?? 'uncategorized',
        );
      }).toList();

      setState(() {
        _searchResults = products;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching products: $e');
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // Dummy categories data - this would normally come from Firebase
  final List<Map<String, dynamic>> dummyCategories = [
    {
      'id': 'bakery',
      'name': 'Bakery',
      'iconCode': 0xe3e6, // bakery_dining icon
      'color': '0xFFF57C00', // Orange
      'imageUrl':
          'https://images.unsplash.com/photo-1608198093002-ad4e005484ec?q=80&w=300',
    },
    {
      'id': 'beverages',
      'name': 'Beverages',
      'iconCode': 0xe544, // local_cafe icon
      'color': '0xFF8E24AA', // Purple
      'imageUrl':
          'https://images.unsplash.com/photo-1595981267035-7b04ca84a82d?q=80&w=300',
    },
    {
      'id': 'dairy',
      'name': 'Dairy',
      'iconCode': 0xef6e, // egg_alt icon
      'color': '0xFF1E88E5', // Blue
      'imageUrl':
          'https://images.unsplash.com/photo-1628088062854-d1870b4553da?q=80&w=300',
    },
    {
      'id': 'fruits',
      'name': 'Fruits',
      'iconCode': 0xe25e, // fruit_alt icon
      'color': '0xFFE53935', // Red
      'imageUrl':
          'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?q=80&w=300',
    },
    {
      'id': 'vegetables',
      'name': 'Vegetables',
      'iconCode': 0xe25a, // eco icon
      'color': '0xFF43A047', // Green
      'imageUrl':
          'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?q=80&w=300',
    },
  ];

  Widget _buildSectionHeader(
      String title, Color indicatorColor, VoidCallback onViewAll) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: indicatorColor,
            ),
            child: Row(
              children: [
                Text('View All'),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(GroceryItem item) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context); // Add this line
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    bool isInCart = cartProvider.cartItemIds
        .contains(item.id); // Use cartProvider instead of _cartItems

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            child: Center(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        item.icon,
                        size: 50,
                        color: primaryColor,
                      ),
                    )
                  : Icon(
                      item.icon,
                      size: 50,
                      color: primaryColor,
                    ),
            ),
          ),

          // Product info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                        if (item.discountPercentage > 0 && item.isSpecialOffer)
                          Text(
                            '₹${item.originalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        // Use cartProvider instead of directly modifying _cartItems
                        if (isInCart) {
                          cartProvider.removeFromCart(item.id);
                        } else {
                          cartProvider.addToCart(item.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isInCart
                              ? primaryColor
                              : themeProvider.isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isInCart
                                ? primaryColor
                                : themeProvider.isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Icon(
                          isInCart
                              ? Icons.shopping_cart
                              : Icons.add_shopping_cart,
                          size: 18,
                          color: isInCart ? Colors.white : primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the categories section with circular images
  Widget _buildCategoriesSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Categories',
          primaryColor,
          () {
            setState(() {
              _selectedIndex = 1; // Switch to categories tab
            });
          },
        ),
        SizedBox(
          height: 120,
          child: StreamBuilder<QuerySnapshot>(
            stream: categoriesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Something went wrong',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                );
              }

              final categories = snapshot.data?.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'name': data['name'] ?? 'Unnamed Category',
                      'imageUrl': data['imageUrl'] ?? '',
                      'color': data['color'] ?? '0xFF1E88E5',
                    };
                  }).toList() ??
                  [];

              if (categories.isEmpty) {
                // If no categories in Firestore, use dummy categories
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dummyCategories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final category = dummyCategories[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category['id'];
                          _selectedCategoryName = category['name'];
                          _isLoadingCategoryProducts = true;
                        });
                        // Load products for this category
                        _loadCategoryProducts(category['id']);
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(int.parse(category['color'])).withOpacity(0.2),
                                image: DecorationImage(
                                  image: NetworkImage(category['imageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category['id'];
                        _selectedCategoryName = category['name'];
                        _isLoadingCategoryProducts = true;
                      });
                      // Load products for this category
                      _loadCategoryProducts(category['id']);
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(int.parse(category['color'])).withOpacity(0.2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(35),
                              child: CachedNetworkImage(
                                imageUrl: category['imageUrl'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.category,
                                  color: primaryColor,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Load products for a specific category
  Future<void> _loadCategoryProducts(String categoryId) async {
    if (!mounted) return;

    try {
      final querySnapshot = await productsRef
          .where('categoryId', isEqualTo: categoryId)
          .get();

      if (!mounted) return;

      final products = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return GroceryItem(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Product',
          price: (data['price'] ?? 0).toDouble(),
          originalPrice:
              (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
          discountPercentage: (data['discountPercentage'] ?? 0).toDouble(),
          unit: data['unit'] ?? 'item',
          imageUrl: data['imageUrl'],
          isPopular: data['isPopular'] ?? false,
          isSpecialOffer: data['isSpecialOffer'] ?? false,
          icon: IconData(
            data['iconCode'] ?? 0xe25e,
            fontFamily: 'MaterialIcons',
          ),
          categoryId: data['categoryId'] ?? 'uncategorized',
        );
      }).toList();

      setState(() {
        _categoryProducts = products;
        _isLoadingCategoryProducts = false;
      });
    } catch (e) {
      print('Error loading category products: $e');
      if (!mounted) return;

      setState(() {
        _categoryProducts = [];
        _isLoadingCategoryProducts = false;
      });
    }
  }

  // Build the home tab content
  Widget _buildHomeContent() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    // If we're showing category products
    if (_selectedCategoryId != null) {
      return _buildCategoryProductsView();
    }

    // If we're showing search results
    if (_isSearching || _searchResults.isNotEmpty) {
      return _buildSearchResultsView();
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () async {
        // Refresh data functionality
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location widget at the top
            _buildLocationWidget(),

            // Search bar - FIXED to make it functional
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for products...',
                    hintStyle: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _searchResults = [];
                        _isSearching = false;
                      });
                    }
                  },
                  onSubmitted: (value) {
                    _searchProducts(value);
                  },
                ),
              ),
            ),

            // Categories section - UPDATED to show circular categories with images
            _buildCategoriesSection(),

            // Special Offers section - Only show if there are special offers
            StreamBuilder<QuerySnapshot>(
              stream: productsRef
                  .where('isSpecialOffer', isEqualTo: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Container(); // Hide section if no special offers
                }

                return Column(
                  children: [
                    _buildSectionHeader(
                      'Special Offers',
                      Colors.orange,
                      () {
                        // View all special offers
                      },
                    ),

                    // Special offers products
                    Container(
                      height: 250,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: productsRef
                            .where('isSpecialOffer', isEqualTo: true)
                            .limit(10)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Something went wrong',
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            );
                          }

                          final products = snapshot.data?.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return GroceryItem(
                                  id: doc.id,
                                  name: data['name'] ?? 'Unnamed Product',
                                  price: (data['price'] ?? 0).toDouble(),
                                  originalPrice: (data['originalPrice'] ??
                                          data['price'] ??
                                          0)
                                      .toDouble(),
                                  discountPercentage:
                                      (data['discountPercentage'] ?? 0)
                                          .toDouble(),
                                  unit: data['unit'] ?? 'item',
                                  imageUrl: data['imageUrl'],
                                  isPopular: data['isPopular'] ?? false,
                                  isSpecialOffer:
                                      data['isSpecialOffer'] ?? false,
                                  icon: IconData(
                                    data['iconCode'] ?? 0xe25e,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  categoryId:
                                      data['categoryId'] ?? 'uncategorized',
                                );
                              }).toList() ??
                              [];

                          if (products.isEmpty) {
                            return Container(); // Hide if no products
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: products.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 16),
                                child: _buildProductCard(products[index]),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            // Popular Products section
            _buildSectionHeader(
              'Popular Products',
              Colors.green,
              () {
                // View all popular products
              },
            ),

            // Popular products grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: productsRef
                    .where('isPopular', isEqualTo: true)
                    .limit(4)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    );
                  }

                  final products = snapshot.data?.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return GroceryItem(
                          id: doc.id,
                          name: data['name'] ?? 'Unnamed Product',
                          price: (data['price'] ?? 0).toDouble(),
                          originalPrice:
                              (data['originalPrice'] ?? data['price'] ?? 0)
                                  .toDouble(),
                          discountPercentage:
                              (data['discountPercentage'] ?? 0).toDouble(),
                          unit: data['unit'] ?? 'item',
                          imageUrl: data['imageUrl'],
                          isPopular: data['isPopular'] ?? false,
                          isSpecialOffer: data['isSpecialOffer'] ?? false,
                          icon: IconData(
                            data['iconCode'] ?? 0xe25e,
                            fontFamily: 'MaterialIcons',
                          ),
                          categoryId: data['categoryId'] ?? 'uncategorized',
                        );
                      }).toList() ??
                      [];

                  if (products.isEmpty) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No popular products available',
                          style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(products[index]);
                    },
                  );
                },
              ),
            ),

            // Recently Viewed section
            _buildSectionHeader(
              'Recently Viewed',
              Colors.purple,
              () {
                // Clear recently viewed
              },
            ),

            // Recently viewed products
            Container(
              height: 250,
              margin: const EdgeInsets.only(bottom: 24),
              child: StreamBuilder<QuerySnapshot>(
                stream: productsRef.limit(10).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }

                  final products = snapshot.data?.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return GroceryItem(
                          id: doc.id,
                          name: data['name'] ?? 'Unnamed Product',
                          price: (data['price'] ?? 0).toDouble(),
                          originalPrice:
                              (data['originalPrice'] ?? data['price'] ?? 0)
                                  .toDouble(),
                          discountPercentage:
                              (data['discountPercentage'] ?? 0).toDouble(),
                          unit: data['unit'] ?? 'item',
                          imageUrl: data['imageUrl'],
                          isPopular: data['isPopular'] ?? false,
                          isSpecialOffer: data['isSpecialOffer'] ?? false,
                          icon: IconData(
                            data['iconCode'] ?? 0xe25e,
                            fontFamily: 'MaterialIcons',
                          ),
                          categoryId: data['categoryId'] ?? 'uncategorized',
                        );
                      }).toList() ??
                      [];

                  if (products.isEmpty) {
                    return Center(
                        child: Text(
                      'No recently viewed products',
                      style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                    ));
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 16),
                        child: _buildProductCard(products[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build search results view
  Widget _buildSearchResultsView() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Column(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              hintStyle: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade500),
              prefixIcon: Icon(Icons.search,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear,
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
            onSubmitted: (value) {
              _searchProducts(value);
            },
          ),
        ),

        // Back button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchResults = [];
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
                icon: Icon(Icons.arrow_back, size: 16, color: primaryColor),
                label:
                    Text('Back to Home', style: TextStyle(color: primaryColor)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isSearching
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search Results (${_searchResults.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                return _buildProductCard(_searchResults[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // Build category products view
  Widget _buildCategoryProductsView() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: themeProvider.isDarkMode
                    ? Colors.black26
                    : Colors.grey.shade200,
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: primaryColor),
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _selectedCategoryName = null;
                    _categoryProducts = [];
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                _selectedCategoryName ?? 'Category Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // Products grid
        Expanded(
          child: _isLoadingCategoryProducts
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : _categoryProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products in this category',
                            style: TextStyle(
                              fontSize: 18,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategoryId = null;
                                _selectedCategoryName = null;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go Back'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _categoryProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_categoryProducts[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    final backgroundColor = themeProvider.isDarkMode
        ? themeProvider.darkBackgroundColor
        : themeProvider.lightBackgroundColor;

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Row(
          children: [
            // CHANGED: Replaced icon with CachedNetworkImage for logo
            Container(
              width: 32, // Increased width for navbar
              height: 32,
              child: CachedNetworkImage(
                imageUrl: "https://media-hosting.imagekit.io/984786fd540f43be/NS-removebg-preview.png?Expires=1839859339&Key-Pair-Id=K2ZIVPTIP2VGHC&Signature=VuSd2Dq9OS7afoetTINCwpcbBrINsmo-K2mr4ktbHayY67Xo-RB6fhtpNJLldtGryaItxF0E5utC528jaEwiSx~58GRIuwrily7jRRZakhHiX8VJl9t8fzI1lVr7nvx6tzxNSx0pOGTNSgwfrWXgIEu40kSSEp8jFpI2Vby52Q~kMKjSDfb6X8IGSEF0lQv5qHfh2XJjEADO1~1pud1XDhZfgbjyPPL5nh~NwhiDKbbUl5x0lV04SADLkJEicEAd6OCFVCsvW3M3jscdp8WqxpVACLfrbfRlYLe-TEjjBnZkjiVhZRanC6aKVASJJdXhkMqDEn1WfFCRdmljmrbOmA__",
                fit: BoxFit.contain,
                placeholder: (context, url) => CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.shopping_basket_rounded,
                  color: primaryColor,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // CHANGED: Updated font style for NammaStore
            Text(
              'NammaStore',
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none,
                color: themeProvider.isDarkMode
                    ? Colors.black
                    : Colors.black),
            onPressed: () {
              // Show notifications
            },
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined,
                color: themeProvider.isDarkMode
                    ? Colors.black
                    : Colors.black),
            onPressed: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
          // Admin access buttons
          if (user?.email == 'admin@gmail.com')
            PopupMenuButton(
              icon: Icon(Icons.admin_panel_settings, color: Colors.black),
              tooltip: 'Admin Options',
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'products',
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text('Manage Products'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'orders',
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text('Manage Orders'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'products') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminProductScreen()),
                  );
                } else if (value == 'orders') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminOrdersScreen()),
                  );
                }
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const CategoriesScreen(),
          const CartScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: themeProvider.isDarkMode
                  ? Colors.black26
                  : Colors.grey.shade200,
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor:themeProvider.isDarkMode
              ? Colors.white
              : Colors.black,
          unselectedItemColor: themeProvider.isDarkMode
              ? Colors.grey
              : Colors.grey.shade600,
          backgroundColor: backgroundColor,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              // Reset search and category views when switching tabs
              if (index != 0) {
                _searchResults = [];
                _isSearching = false;
                _selectedCategoryId = null;
                _selectedCategoryName = null;
              }
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              activeIcon: Icon(Icons.category),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
