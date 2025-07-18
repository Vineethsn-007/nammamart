// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:namma_mart/providers/cart_provider.dart';
import 'package:namma_mart/screens/admin_orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart' show Selector;
import '../models/grocery_item.dart';
import '../providers/theme_provider.dart';
import 'admin_product_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../providers/address_provider.dart';
import '../widgets/address_selection_dialog.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
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
  Timer? _searchDebounce;

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
  bool _phoneNumberDialogShown = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _initializeFirebaseData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkLocationPermission();
        _showPhoneNumberDialogIfNeeded();
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _initializeFirebaseData() async {
    try {
      final categoriesSnapshot = await categoriesRef.limit(1).get();
      if (categoriesSnapshot.docs.isEmpty) {
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

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionGranted = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionGranted = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionGranted = false;
        });
        return;
      }

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
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
        forceAndroidLocationManager: true,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });

      await _getAddressFromLatLng();
    } catch (e) {
      print('Error getting position: $e');

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );

        if (!mounted) return;

        setState(() {
          _currentPosition = position;
        });

        await _getAddressFromLatLng();
        return;
      } catch (fallbackError) {
        print('Fallback location error: $fallbackError');

        if (!mounted) return;

        setState(() {
          _isLoadingLocation = false;
        });

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

        String fullAddress = addressComponents.join(', ');

        setState(() {
          _currentAddress = fullAddress;
          _isLoadingLocation = false;
        });

        final addressProvider =
            Provider.of<AddressProvider>(context, listen: false);
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

        _showAddressSelectionDialog();
      }
    } catch (e) {
      print('Error getting address: $e');
      if (!mounted) return;

      setState(() {
        _currentAddress = 'Error getting address';
        _isLoadingLocation = false;
      });

      _showAddressSelectionDialog();
    }
  }

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
      // Only match products whose name starts with the query (case-insensitive)
      final lowerQuery = query.toLowerCase();
      final upperBound = lowerQuery.substring(0, lowerQuery.length - 1) +
          String.fromCharCode(lowerQuery.codeUnitAt(lowerQuery.length - 1) + 1);
      final querySnapshot = await productsRef
          .where('nameSearch', isGreaterThanOrEqualTo: lowerQuery)
          .where('nameSearch', isLessThan: upperBound)
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

  final List<Map<String, dynamic>> dummyCategories = [
    {
      'id': 'all',
      'name': 'All',
      'iconCode': 0xe59c, // shopping_basket
      'color': '0xFFFF9800', // Orange
      'imageUrl':
          'https://images.unsplash.com/photo-1608198093002-ad4e005484ec?q=80&w=300',
    },
    {
      'id': 'maxxsaver',
      'name': 'Maxxsaver',
      'iconCode': 0xe54e, // local_offer
      'color': '0xFF4CAF50', // Green
      'imageUrl':
          'https://images.unsplash.com/photo-1595981267035-7b04ca84a82d?q=80&w=300',
    },
    {
      'id': 'fresh',
      'name': 'Fresh',
      'iconCode': 0xe25e, // fruit_alt
      'color': '0xFFFF9800', // Orange
      'imageUrl':
          'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?q=80&w=300',
    },
    {
      'id': 'monsoon',
      'name': 'Monsoon',
      'iconCode': 0xe3e6, // umbrella
      'color': '0xFF2196F3', // Blue
      'imageUrl':
          'https://images.unsplash.com/photo-1628088062854-d1870b4553da?q=80&w=300',
    },
    {
      'id': 'gadgets',
      'name': 'Gadgets',
      'iconCode': 0xe1b8, // phone_android
      'color': '0xFF9C27B0', // Purple
      'imageUrl':
          'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?q=80&w=300',
    },
    {
      'id': 'home',
      'name': 'Home',
      'iconCode': 0xe88a, // home
      'color': '0xFFE91E63', // Pink
      'imageUrl':
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?q=80&w=300',
    },
  ];

  Widget _buildSectionHeader(String title, Color indicatorColor,
      VoidCallback onViewAll, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode
                  ? themeProvider.lightPrimaryColor
                  : Colors.black,
            ),
          ),
          TextButton.icon(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: EdgeInsets.zero,
            ),
            icon: const Text('See All'),
            label: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      GroceryItem item, bool isDark, ThemeProvider themeProvider) {
    final cartProvider = Provider.of<CartProvider>(context);
    bool isInCart = cartProvider.cartItemIds.contains(item.id);

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? themeProvider.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image with add button
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          cacheManager: DefaultCacheManager(),
                          cacheKey: item.imageUrl,
                          height: 140,
                          width: 140,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.purple),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            item.icon,
                            size: 90,
                            color: Colors.purple,
                          ),
                        )
                      : Icon(
                          item.icon,
                          size: 90,
                          color: Colors.purple,
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if (isInCart) {
                        cartProvider.removeFromCart(item.id);
                      } else {
                        cartProvider.addToCart(item.id);
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: isInCart ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.unit,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (item.discountPercentage > 0 && item.isSpecialOffer)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.discountPercentage.toInt()}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (item.discountPercentage > 0 && item.isSpecialOffer) ...[
                      const SizedBox(width: 4),
                      Text(
                        '₹${item.originalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                          fontSize: 12,
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

  Widget _buildCategoriesSection() {
    return Column(
      children: [
        SizedBox(
          height: 100,
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
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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
                      'iconCode': data['iconCode'] ?? 0xe59c,
                    };
                  }).toList() ??
                  [];

              if (categories.isEmpty) {
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
                        _loadCategoryProducts(category['id']);
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Color(int.parse(category['color']))
                                    .withOpacity(0.2),
                              ),
                              child: Icon(
                                IconData(
                                  category['iconCode'],
                                  fontFamily: 'MaterialIcons',
                                ),
                                size: 28,
                                color: Color(int.parse(category['color'])),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
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
                      _loadCategoryProducts(category['id']);
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Color(int.parse(category['color']))
                                  .withOpacity(0.2),
                            ),
                            child: Icon(
                              IconData(
                                category['iconCode'],
                                fontFamily: 'MaterialIcons',
                              ),
                              size: 28,
                              color: Color(int.parse(category['color'])),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
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

  Future<void> _loadCategoryProducts(String categoryId) async {
    if (!mounted) return;

    try {
      final querySnapshot =
          await productsRef.where('categoryId', isEqualTo: categoryId).get();

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

  Widget _buildPromotionalBanners() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.lightPrimaryColor;
    final List<Map<String, dynamic>> banners = [
      {
        'title': 'Dairy, eggs\n& more',
        'discount': 'UP TO 30% OFF',
      },
      {
        'title': 'Chicken, meat\n& seafood',
        'discount': 'UP TO 30% OFF',
      },
      {
        'title': 'Season\'s\nfreshest fruits',
        'discount': 'UP TO 70% OFF',
      },
      {
        'title': 'Cold cuts &\nmarinades',
        'discount': 'UP TO 20% OFF',
      },
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final banner = banners[index];
          final offerColors = [
            isDark ? Color(0xFF6A1B9A) : Color(0xFF9C27B0), // Purple
            isDark ? Color(0xFF1565C0) : Color(0xFF2196F3), // Blue
            isDark ? Color(0xFFFF9800) : Color(0xFFFF9800), // Orange
            isDark ? Color(0xFFB71C1C) : Color(0xFFE53935), // Red
          ];
          final cardColor = offerColors[index % offerColors.length];
          final textColor = _getBannerTextColor(cardColor);
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            banner['discount'],
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          banner['title'],
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.2)
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_basket,
                        color: textColor,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_selectedCategoryId != null) {
      return _buildCategoryProductsView();
    }

    if (_isSearching || _searchResults.isNotEmpty) {
      return _buildSearchResultsView();
    }

    return RefreshIndicator(
      color: Colors.purple,
      onRefresh: () async {
        await _initializeFirebaseData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // (Categories section removed)
            const SizedBox(height: 8),

            // Promotional banners
            _buildPromotionalBanners(),

            const SizedBox(height: 24),

            // All products section
            _buildSectionHeader(
              'All Products',
              Colors.orange,
              () {},
              themeProvider,
            ),

            Container(
              height: 320,
              margin: const EdgeInsets.only(bottom: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: productsRef.limit(30).snapshots(),
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
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.purple),
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
                    return const Center(
                      child: Text('No products available'),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final isDark = themeProvider.isDarkMode;
                      return _buildProductCard(
                          products[index], isDark, themeProvider);
                    },
                  );
                },
              ),
            ),

            // Special Offers section
            _buildSectionHeader(
              'Special Offers',
              Colors.red,
              () {},
              themeProvider,
            ),

            Container(
              height: 320,
              margin: const EdgeInsets.only(bottom: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: productsRef
                    .where('isSpecialOffer', isEqualTo: true)
                    .limit(20)
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
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.purple),
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
                    return const Center(
                      child: Text('No special offers available'),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final isDark = themeProvider.isDarkMode;
                      return _buildProductCard(
                          products[index], isDark, themeProvider);
                    },
                  );
                },
              ),
            ),

            // Free delivery banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Color.fromARGB(255, 251, 158, 18),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'FREE DELIVERY on orders above ₹49',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade400),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: const TextStyle(color: Colors.black87),
            onChanged: (value) {
              // Debounce search to avoid excessive Firestore queries
              _searchDebounce?.cancel();
              if (value.isEmpty) {
                setState(() {
                  _searchResults = [];
                  _isSearching = false;
                });
              } else {
                _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                  _searchProducts(value);
                });
              }
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                )
              : _searchResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
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
                                final themeProvider =
                                    Provider.of<ThemeProvider>(context);
                                final isDark = themeProvider.isDarkMode;
                                return _buildProductCard(_searchResults[index],
                                    isDark, themeProvider);
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

  Widget _buildCategoryProductsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.purple),
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCategoryProducts
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                )
              : _categoryProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No products in this category',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
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
                              backgroundColor: Colors.purple,
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
                          final themeProvider =
                              Provider.of<ThemeProvider>(context);
                          final isDark = themeProvider.isDarkMode;
                          return _buildProductCard(
                              _categoryProducts[index], isDark, themeProvider);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    final isDark = context.select<ThemeProvider, bool>((tp) => tp.isDarkMode);
    final backgroundColor = isDark
        ? context.select<ThemeProvider, Color>((tp) => tp.darkBackgroundColor)
        : context.select<ThemeProvider, Color>((tp) => tp.lightBackgroundColor);

    return Container(
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: context
              .select<ThemeProvider, Color>((tp) => tp.lightPrimaryColor),
          elevation: 0,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CachedNetworkImage(
                    imageUrl:
                        "https://media-hosting.imagekit.io/984786fd540f43be/NS-removebg-preview.png?Expires=1839859339&Key-Pair-Id=K2ZIVPTIP2VGHC&Signature=VuSd2Dq9OS7afoetTINCwpcbBrINsmo-K2mr4ktbHayY67Xo-RB6fhtpNJLldtGryaItxF0E5utC528jaEwiSx~58GRIuwrily7jRRZakhHiX8VJl9t8fzI1lVr7nvx6tzxNSx0pOGTNSgwfrWXgIEu40kSSEp8jFpI2Vby52Q~kMkjSDfb6X8IGSEF0lQv5qHfh2XJjEADO1~1pud1XDhZfgbjyPPL5nh~NwhiDKbbUl5x0lV04SADLkJEicEAd6OCFVCsvW3M3jscdp8WqxpVACLfrbfRlYLe-TEjjBnZkjiVhZRanC6aKVASJJdXhkMqDEn1WfFCRdmljmrbOmA__",
                    fit: BoxFit.contain,
                    placeholder: (context, url) => CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.shopping_basket_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Center(
                child: Text(
                  'NammaMart',
                  style: GoogleFonts.roboto(
                    textStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () {
                setState(() {
                  _selectedIndex = 2;
                });
              },
            ),
            if (user?.email == 'admin@gmail.com')
              PopupMenuButton(
                icon: Icon(
                  Icons.admin_panel_settings,
                  color: isDark ? Colors.white : Colors.black,
                ),
                tooltip: 'Admin Options',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'products',
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text('Manage Products'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'orders',
                    child: Row(
                      children: [
                        Icon(Icons.shopping_bag,
                            color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text('Manage Orders'),
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
        body: Column(
          children: [
            if (_selectedIndex == 0 && !_isSearching && _searchResults.isEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                      color: context.select<ThemeProvider, Color>(
                          (tp) => tp.lightPrimaryColor),
                      width: 3),
                  borderRadius: BorderRadius.circular(33),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.select<ThemeProvider, Color>(
                            (tp) => tp.darkBackgroundColor)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search for 'Fruits' or 'Vegetables'",
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? context.select<ThemeProvider, Color>(
                                  (tp) => tp.darkCardColor)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.list_alt, size: 16),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    onChanged: (value) {
                      // Debounce search to avoid excessive Firestore queries
                      _searchDebounce?.cancel();
                      if (value.isEmpty) {
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      } else {
                        _searchDebounce =
                            Timer(const Duration(milliseconds: 400), () {
                          _searchProducts(value);
                        });
                      }
                    },
                    onSubmitted: (value) {
                      _searchProducts(value);
                    },
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // If searching, show only the search results view
                  (_isSearching || _searchResults.isNotEmpty)
                      ? _buildSearchResultsView()
                      : _buildHomeContent(),
                  const CategoriesScreen(),
                  const CartScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark
                ? context.select<ThemeProvider, Color>((tp) => tp.darkCardColor)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.grey.shade200,
                offset: const Offset(0, -2),
                blurRadius: 10,
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: isDark ? Colors.white : Colors.black,
            unselectedItemColor:
                isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            backgroundColor: isDark
                ? context.select<ThemeProvider, Color>((tp) => tp.darkCardColor)
                : Colors.white,
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
      ),
    );
  }

  Future<void> _showPhoneNumberDialogIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'phoneNumberCollected_${user.uid}';
    final alreadyCollected = prefs.getBool(key) ?? false;
    if (!alreadyCollected && !_phoneNumberDialogShown) {
      _phoneNumberDialogShown = true;

      // Create controllers outside the builder to prevent recreation
      final TextEditingController phoneController = TextEditingController();
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          final primaryColor = themeProvider.lightPrimaryColor;

          return StatefulBuilder(
            builder: (context, setState) {
              bool isSaving = false;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Enter your phone number',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 24),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We need your phone number for order updates and delivery.',
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: formKey,
                          child: TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Phone Number',
                              prefixIcon: const Icon(Icons.phone),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              final phoneRegExp = RegExp(r'^[0-9]{10,15}$');
                              if (!phoneRegExp.hasMatch(value.trim())) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() ??
                                        false) {
                                      setState(() => isSaving = true);
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .set({
                                          'phone': phoneController.text.trim()
                                        }, SetOptions(merge: true));
                                        await prefs.setBool(key, true);
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        setState(() => isSaving = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to save phone number. Please try again.')),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text('Continue'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Your number is kept private and secure.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }
}

// Add a helper function for contrast
Color _getBannerTextColor(Color bg) {
  // Use white for dark backgrounds, black for light backgrounds
  // Purple and Red are dark, Blue and Orange are light
  if (bg == Color(0xFF9C27B0) || bg == Color(0xFFE53935)) {
    return Colors.white;
  } else {
    return Colors.black;
  }
}
