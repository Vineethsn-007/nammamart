import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/grocery_item.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/network_aware_widget.dart';

class AllProductsScreen extends StatefulWidget {
  final String? categoryFilter;
  final String? title;

  const AllProductsScreen({
    Key? key,
    this.categoryFilter,
    this.title,
  }) : super(key: key);

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final productsRef = FirebaseFirestore.instance.collection('products');

  // Search functionality
  late TextEditingController _searchController;
  List<GroceryItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
      } else {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    // Search in Firestore
    final searchQuery = query.toLowerCase();
    productsRef.get().then((snapshot) {
      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final description =
            (data['description'] ?? '').toString().toLowerCase();
        return name.contains(searchQuery) || description.contains(searchQuery);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = results.map((doc) {
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
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = isDark
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    final backgroundColor = isDark
        ? themeProvider.darkBackgroundColor
        : themeProvider.lightBackgroundColor;

    return Container(
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: Text(
            widget.title ?? 'All Products',
            style: GoogleFonts.poppins(
              textStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.search,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () {
                _showSearchBar();
              },
            ),
          ],
        ),
        body: NetworkAwareWidget(
          onlineChild: Column(
            children: [
              // Search bar
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                            _searchResults.clear();
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? themeProvider.darkCardColor : Colors.white,
                    ),
                  ),
                ),

              // Products grid
              Expanded(
                child: _isSearching
                    ? _buildSearchResults(isDark, themeProvider)
                    : _buildAllProducts(isDark, themeProvider),
              ),
            ],
          ),
          offlineChild: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection and try again',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark, ThemeProvider themeProvider) {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_searchResults[index], isDark, themeProvider);
      },
    );
  }

  Widget _buildAllProducts(bool isDark, ThemeProvider themeProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.categoryFilter != null
          ? productsRef
              .where('categoryId', isEqualTo: widget.categoryFilter)
              .snapshots()
          : widget.title == 'Special Offers'
              ? productsRef.where('isSpecialOffer', isEqualTo: true).snapshots()
              : productsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
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

        final products = snapshot.data?.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return GroceryItem(
                id: doc.id,
                name: data['name'] ?? 'Unnamed Product',
                price: (data['price'] ?? 0).toDouble(),
                originalPrice:
                    (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No products available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new products',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _buildProductCard(products[index], isDark, themeProvider);
          },
        );
      },
    );
  }

  Widget _buildProductCard(
      GroceryItem item, bool isDark, ThemeProvider themeProvider) {
    return Container(
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
                  child: Selector<CartProvider, Map<String, dynamic>>(
                    selector: (context, cartProvider) => {
                      'isInCart': cartProvider.cartItemIds.contains(item.id),
                      'quantity': cartProvider.itemQuantities[item.id] ?? 0,
                    },
                    builder: (context, cartData, child) {
                      final isInCart = cartData['isInCart'] as bool;
                      final quantity = cartData['quantity'] as int;

                      if (!isInCart) {
                        // Show simple add button when not in cart (home page style)
                        return GestureDetector(
                          onTap: () {
                            final cartProvider = Provider.of<CartProvider>(
                                context,
                                listen: false);
                            cartProvider.addToCart(item.id);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
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
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      } else {
                        // Show quantity selector when in cart (home page style)
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Minus button
                              GestureDetector(
                                onTap: () {
                                  final cartProvider =
                                      Provider.of<CartProvider>(context,
                                          listen: false);
                                  if (quantity > 1) {
                                    cartProvider.updateQuantity(
                                        item.id, quantity - 1);
                                  } else {
                                    cartProvider.removeFromCart(item.id);
                                  }
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              // Quantity display
                              Container(
                                width: 32,
                                height: 28,
                                alignment: Alignment.center,
                                child: Text(
                                  quantity.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              // Plus button
                              GestureDetector(
                                onTap: () {
                                  final cartProvider =
                                      Provider.of<CartProvider>(context,
                                          listen: false);
                                  cartProvider.updateQuantity(
                                      item.id, quantity + 1);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
                // Discount badge
                if (item.discountPercentage > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '-${item.discountPercentage.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Product details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    if (item.originalPrice > item.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        '₹${item.originalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'per ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchBar() {
    setState(() {
      _isSearching = true;
    });
  }
}
