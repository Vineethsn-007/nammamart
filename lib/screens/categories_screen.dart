import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final categoriesRef = FirebaseFirestore.instance.collection('categories');
  
  @override
  void initState() {
    super.initState();
    _updateCategoryItemCounts();
  }
  
  // Update the build method to remove any padding between app bar and content
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
          'Categories',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: primaryColor),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CategorySearchDelegate(primaryColor),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: primaryColor),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
        // Remove bottom padding from app bar
        bottom: PreferredSize(
          preferredSize: Size.zero,
          child: Container(),
        ),
      ),
      body: Column(
        children: [
          // Featured categories horizontal list
          _buildFeaturedCategories(),
          
          // Main categories grid
          Expanded(
            child: _buildCategoriesGrid(),
          ),
        ],
      ),
    );
  }
  
  // Update the _buildFeaturedCategories method to remove the top margin
  Widget _buildFeaturedCategories() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      height: 120, // Reduced height to remove extra space
      padding: EdgeInsets.zero, // Remove all padding
      margin: EdgeInsets.zero, // Remove all margins
      child: StreamBuilder<QuerySnapshot>(
        stream: categoriesRef.where('featured', isEqualTo: true).limit(5).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildFeaturedCategoriesSkeleton();
          }
          
          final featuredCategories = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'],
              'color': data['color'],
              'imageUrl': data['imageUrl'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=300',
              'itemCount': data['itemCount'] ?? 0,
            };
          }).toList() ?? [];
          
          if (featuredCategories.isEmpty) {
            return const SizedBox.shrink();
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: featuredCategories.length,
            itemBuilder: (context, index) {
              final category = featuredCategories[index];
              final Color categoryColor = Color(int.parse(category['color']));
              
              return GestureDetector(
                onTap: () {
                  _navigateToProductsScreen(category['id'], category['name']);
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: categoryColor.withOpacity(0.1),
                              border: Border.all(
                                color: categoryColor.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: categoryColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: category['imageUrl'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.category,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ),
                          // Add item count badge
                          if (category['itemCount'] > 0)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: categoryColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${category['itemCount']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: categoryColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category['itemCount']} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.isDarkMode 
                              ? Colors.grey.shade400 
                              : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
          },
        );
      },
    ),
  );
}
  
  Widget _buildFeaturedCategoriesSkeleton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final baseColor = themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = themeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[100]!;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: 100,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCategoriesGrid() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return StreamBuilder<QuerySnapshot>(
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
          return _buildCategoriesGridSkeleton();
        }
        
        final categories = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'],
            'iconCode': data['iconCode'],
            'color': data['color'],
            'imageUrl': data['imageUrl'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=300',
            'itemCount': data['itemCount'] ?? 0,
          };
        }).toList() ?? [];
        
        if (categories.isEmpty) {
          return _buildEmptyState();
        }
        
        return RefreshIndicator(
          color: themeProvider.isDarkMode 
              ? themeProvider.darkPrimaryColor 
              : themeProvider.lightPrimaryColor,
          onRefresh: () async {
            setState(() {});
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(categories[index]);
            },
          ),
        );
      },
    );
  }
  
  // Update the _buildCategoryCard method to show item count more prominently
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final Color categoryColor = Color(int.parse(category['color']));
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        _navigateToProductsScreen(category['id'], category['name']);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: themeProvider.isDarkMode 
                  ? Colors.black26 
                  : Colors.grey.shade200,
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Hero(
                    tag: 'category_image_${category['id']}',
                    child: CachedNetworkImage(
                      imageUrl: category['imageUrl'],
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        highlightColor: themeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                        child: Container(
                          height: 120,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 120,
                        color: categoryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.image_not_supported,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay for better text visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Enhanced category count badge with more prominence
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            size: 14,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${category['itemCount']} items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category name at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Text(
                        category['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Add item count text with icon
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: themeProvider.isDarkMode 
                              ? Colors.grey.shade400 
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${category['itemCount']} products available',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade400 
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _navigateToProductsScreen(category['id'], category['name']);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: categoryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Products',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: categoryColor,
                              size: 12,
                            ),
                          ],
                        ),
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
  
  Widget _buildCategoriesGridSkeleton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final baseColor = themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = themeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[100]!;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
  
  
  
  // Navigate to products screen
  void _navigateToProductsScreen(String categoryId, String categoryName) {
    // Navigate to products screen with category ID and name
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductsScreen(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    // For demonstration purposes, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $categoryName products'),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  Widget _buildEmptyState() {
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
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.category_outlined,
              size: 64,
              color: primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No categories available',
            style: TextStyle(
              fontSize: 18,
              color: themeProvider.isDarkMode 
                  ? Colors.grey.shade300 
                  : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates',
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.isDarkMode 
                  ? Colors.grey.shade400 
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterBottomSheet(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: themeProvider.isDarkMode 
                    ? Colors.black26 
                    : Colors.grey.shade300,
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
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  _buildFilterChip('Newest', true),
                  _buildFilterChip('Popularity', false),
                  _buildFilterChip('A-Z', false),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Category Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  _buildFilterChip('All', true),
                  _buildFilterChip('Featured', false),
                  _buildFilterChip('Seasonal', false),
                  _buildFilterChip('Trending', false),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildFilterChip(String label, bool isSelected) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        // Handle filter selection
      },
      selectedColor: primaryColor.withOpacity(0.2),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : themeProvider.isDarkMode ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : themeProvider.isDarkMode 
              ? Colors.grey.shade700 
              : Colors.grey.shade300,
        ),
      ),
      elevation: isSelected ? 1 : 0,
      shadowColor: isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
    );
  }
  
  // Add a method to fetch category item counts from Firestore
  Future<void> _updateCategoryItemCounts() async {
    try {
      // Get all products
      final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
      
      // Count products by category
      Map<String, int> categoryCounts = {};
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final categoryId = data['categoryId'] as String?;
        if (categoryId != null) {
          categoryCounts[categoryId] = (categoryCounts[categoryId] ?? 0) + 1;
        }
      }
      
      // Update each category with its count
      for (var entry in categoryCounts.entries) {
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(entry.key)
            .update({'itemCount': entry.value});
      }
      
      // Refresh the UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error updating category item counts: $e');
    }
  }
}

// Search delegate for categories
class CategorySearchDelegate extends SearchDelegate<String> {
  final Color primaryColor;
  
  CategorySearchDelegate(this.primaryColor);
  
  @override
  ThemeData appBarTheme(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? themeProvider.darkCardColor : Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 18,
        ),
      ),
    );
  }
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('categories')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }
        
        final results = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'],
            'color': data['color'],
            'imageUrl': data['imageUrl'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=300',
          };
        }).toList() ?? [];
        
        if (results.isEmpty) {
          return Center(
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
                  'No categories found',
                  style: TextStyle(
                    fontSize: 18,
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final category = results[index];
            final Color categoryColor = Color(int.parse(category['color']));
            
            return ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: categoryColor.withOpacity(0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    category['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.category,
                      color: categoryColor,
                    ),
                  ),
                ),
              ),
              title: Text(
                category['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              onTap: () {
                close(context, category['id']);
                // Navigate to products screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductsScreen(
                      categoryId: category['id'],
                      categoryName: category['name'],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

// Products Screen (Placeholder)
class ProductsScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  
  const ProductsScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? themeProvider.darkBackgroundColor 
          : themeProvider.lightBackgroundColor,
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('products')
            .where('categoryId', isEqualTo: categoryId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading products: ${snapshot.error}',
                style: TextStyle(color: Colors.red.shade800),
              ),
            );
          }
          
          final products = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Product',
              'price': (data['price'] ?? 0).toDouble(),
              'originalPrice': (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
              'discountPercentage': (data['discountPercentage'] ?? 0).toDouble(),
              'unit': data['unit'] ?? 'item',
              'imageUrl': data['imageUrl'],
            };
          }).toList() ?? [];
          
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade600 
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No products available in this category',
                    style: TextStyle(
                      fontSize: 18,
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade400 
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(context, product);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black26 
                : Colors.grey.shade200,
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: product['imageUrl'] != null
                ? CachedNetworkImage(
                    imageUrl: product['imageUrl'],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade100,
                      child: Icon(
                        Icons.image_not_supported,
                        color: themeProvider.isDarkMode 
                            ? Colors.grey.shade600 
                            : Colors.grey.shade400,
                      ),
                    ),
                  )
                : Container(
                    height: 120,
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade100,
                    child: Icon(
                      Icons.image_not_supported,
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade600 
                          : Colors.grey.shade400,
                    ),
                  ),
          ),
          
          // Product details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['unit'],
                    style: TextStyle(
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade400 
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '₹${product['price'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (product['discountPercentage'] > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${product['originalPrice'].toStringAsFixed(2)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade500 
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product['discountPercentage'] > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode 
                            ? Colors.red.shade900.withOpacity(0.3) 
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product['discountPercentage'].toStringAsFixed(0)}% OFF',
                        style: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Colors.red.shade300 
                              : Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Add to cart button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_shopping_cart,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add to Cart',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
