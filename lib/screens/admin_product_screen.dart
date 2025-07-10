// screens/admin_product_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:namma_store/screens/admin_orders_screen.dart';
import '../models/grocery_item.dart';

class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({Key? key}) : super(key: key);

  @override
  _AdminProductScreenState createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen>
    with SingleTickerProviderStateMixin {
  // Firestore references
  final productsRef = FirebaseFirestore.instance.collection('products');
  final categoriesRef = FirebaseFirestore.instance.collection('categories');
  final storageRef = FirebaseStorage.instance.ref();

  // Form controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountPercentageController = TextEditingController();
  final _unitController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _searchController = TextEditingController();
  

  // Category form controllers
  final _categoryNameController = TextEditingController();
  final _categoryIconCodeController = TextEditingController();
  final _categoryColorController = TextEditingController();
  final _categoryImageUrlController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Form key for category validation
  final _categoryFormKey = GlobalKey<FormState>();

  // State variables
  String? _selectedCategoryId;
  bool _isPopular = false;
  bool _isSpecialOffer = false;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isEditing = false;
  bool _isEditingCategory = false;
  String? _currentProductId;
  String? _currentCategoryId;
  File? _imageFile;
  File? _categoryImageFile;
  List<Map<String, dynamic>> _categories = [];
  List<GroceryItem> _products = [];
  List<GroceryItem> _filteredProducts = [];

  // Sorting and filtering
  String _sortBy = 'name';
  bool _sortAscending = true;
  String? _filterCategory;

  // Tab controller
  late TabController _tabController;

  // Colors
  final Color primaryColor = const Color(0xFF1E88E5);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color errorColor = const Color(0xFFE53935);
  final Color successColor = const Color(0xFF43A047);

  // Settings form controllers
  final _deliveryFeeController = TextEditingController();
  final _taxRateController = TextEditingController();
  
  // Settings form key
  final _settingsFormKey = GlobalKey<FormState>();
  
  // Default values
  double _deliveryFee = 40.0;
  double _taxRate = 5.0;
  bool _isLoadingSettings = false;
  bool _isUpdatingSettings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCategories();
    _loadSettings();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _discountPercentageController.dispose();
    _unitController.dispose();
    _imageUrlController.dispose();
    _searchController.dispose();
    _categoryNameController.dispose();
    _categoryIconCodeController.dispose();
    _categoryColorController.dispose();
    _categoryImageUrlController.dispose();
    _deliveryFeeController.dispose();
    _taxRateController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Load categories from Firestore
  Future<void> _loadCategories() async {
    try {
      final snapshot = await categoriesRef.get();
      setState(() {
        _categories =
            snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unnamed Category',
                'color': data['color'] ?? '0xFF1E88E5',
                'iconCode': data['iconCode'] ?? 0xe25e,
                'imageUrl': data['imageUrl'] ?? '',
              };
            }).toList();

        // Sort categories alphabetically
        _categories.sort((a, b) => a['name'].compareTo(b['name']));
      });
    } catch (e) {
      _showErrorSnackBar('Error loading categories: $e');
    }
  }

  // Load products from Firestore
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await productsRef.get();
      final List<GroceryItem> loadedProducts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedProducts.add(
          GroceryItem(
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
            categoryId: data['categoryId'] ?? '',
          ),
        );
      }

      setState(() {
        _products = loadedProducts;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading products: $e');
    }
  }

  // Apply filters and sorting to products
  void _applyFiltersAndSort() {
    List<GroceryItem> filtered = List.from(_products);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered =
          filtered
              .where(
                (product) =>
                    product.name.toLowerCase().contains(searchTerm) ||
                    product.unit.toLowerCase().contains(searchTerm),
              )
              .toList();
    }

    // Apply category filter
    if (_filterCategory != null) {
      filtered =
          filtered
              .where((product) => product.categoryId == _filterCategory)
              .toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'name':
          result = a.name.compareTo(b.name);
          break;
        case 'price':
          result = a.price.compareTo(b.price);
          break;
        case 'discount':
          result = a.discountPercentage.compareTo(b.discountPercentage);
          break;
        default:
          result = a.name.compareTo(b.name);
      }

      return _sortAscending ? result : -result;
    });

    setState(() {
      _filteredProducts = filtered;
    });
  }

  // Reset form fields
  void _resetForm() {
    setState(() {
      _nameController.clear();
      _priceController.clear();
      _originalPriceController.clear();
      _discountPercentageController.clear();
      _unitController.clear();
      _imageUrlController.clear();
      _selectedCategoryId = null;
      _isPopular = false;
      _isSpecialOffer = false;
      _isEditing = false;
      _currentProductId = null;
      _imageFile = null;
    });
  }

  // Reset category form fields
  void _resetCategoryForm() {
    setState(() {
      _categoryNameController.clear();
      _categoryIconCodeController.text = '0xe25e'; // Default icon code
      _categoryColorController.text = '0xFF1E88E5'; // Default color
      _categoryImageUrlController.clear();
      _isEditingCategory = false;
      _currentCategoryId = null;
      _categoryImageFile = null;
    });
  }

  // Fill form with product data for editing
  void _editProduct(GroceryItem product) {
    setState(() {
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _originalPriceController.text = product.originalPrice.toString();
      _discountPercentageController.text =
          product.discountPercentage.toString();
      _unitController.text = product.unit;
      _imageUrlController.text = product.imageUrl ?? '';
      _selectedCategoryId = product.categoryId;
      _isPopular = product.isPopular;
      _isSpecialOffer = product.isSpecialOffer;
      _isEditing = true;
      _currentProductId = product.id;
      _imageFile = null;

      // Switch to add/edit tab
      _tabController.animateTo(0);
    });
  }

  // Fill form with category data for editing
  void _editCategory(Map<String, dynamic> category) {
    setState(() {
      _categoryNameController.text = category['name'];
      _categoryIconCodeController.text = category['iconCode']?.toString() ?? '0xe25e';
      _categoryColorController.text = category['color'] ?? '0xFF1E88E5';
      _categoryImageUrlController.text = category['imageUrl'] ?? '';
      _isEditingCategory = true;
      _currentCategoryId = category['id'];
      _categoryImageFile = null;
    });
  }

  // Delete product with confirmation
  Future<void> _deleteProduct(String productId) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Product'),
                content: const Text(
                  'Are you sure you want to delete this product? This action cannot be undone.',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Delete', style: TextStyle(color: errorColor)),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the product to check if it has an image
      final productDoc = await productsRef.doc(productId).get();
      final productData = productDoc.data();
      final imageUrl = productData?['imageUrl'] as String?;

      // Delete the product from Firestore
      await productsRef.doc(productId).delete();

      // Delete the image from Storage if it exists and is from our storage
      if (imageUrl != null && imageUrl.contains('firebase')) {
        try {
          // Extract the file name from the URL
          final fileName = imageUrl.split('/').last.split('?').first;
          await FirebaseStorage.instance
              .ref('product_images/$fileName')
              .delete();
        } catch (e) {
          // Ignore errors when deleting images
          print('Error deleting image: $e');
        }
      }

      // Refresh the product list
      await _loadProducts();

      _showSuccessSnackBar('Product deleted successfully');

      // Reset form if we were editing this product
      if (_currentProductId == productId) {
        _resetForm();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error deleting product: $e');
    }
  }

  // Delete category with confirmation
  Future<void> _deleteCategory(String categoryId) async {
    // Check if category has products
    final productsSnapshot = await productsRef.where('categoryId', isEqualTo: categoryId).limit(1).get();
    if (productsSnapshot.docs.isNotEmpty) {
      _showErrorSnackBar('Cannot delete category with products. Remove or reassign products first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'Are you sure you want to delete this category? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the category to check if it has an image
      final categoryDoc = await categoriesRef.doc(categoryId).get();
      final categoryData = categoryDoc.data();
      final imageUrl = categoryData?['imageUrl'] as String?;

      // Delete the category from Firestore
      await categoriesRef.doc(categoryId).delete();

      // Delete the image from Storage if it exists and is from our storage
      if (imageUrl != null && imageUrl.contains('firebase')) {
        try {
          // Extract the file name from the URL
          final fileName = imageUrl.split('/').last.split('?').first;
          await FirebaseStorage.instance.ref('category_images/$fileName').delete();
        } catch (e) {
          // Ignore errors when deleting images
          print('Error deleting image: $e');
        }
      }

      // Refresh the category list
      await _loadCategories();

      _showSuccessSnackBar('Category deleted successfully');

      // Reset form if we were editing this category
      if (_currentCategoryId == categoryId) {
        _resetCategoryForm();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error deleting category: $e');
    }
  }

  // Save product (create or update)
  // Fix for the _saveProduct method
  Future<void> _saveProduct() async {
  // Validate form
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Parse form values
    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final originalPrice = _originalPriceController.text.trim().isNotEmpty
        ? double.parse(_originalPriceController.text.trim())
        : price;
    final discountPercentage = _discountPercentageController.text.trim().isNotEmpty
        ? double.parse(_discountPercentageController.text.trim())
        : 0.0;
    final unit = _unitController.text.trim();
    String? imageUrl = _imageUrlController.text.trim();

    // Upload image if selected
    if (_imageFile != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Create a unique filename
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = storageRef.child('product_images/$fileName');

        // Upload the file to Firebase Storage
        final uploadTask = ref.putFile(_imageFile!);
        final TaskSnapshot snapshot = await uploadTask;

        // Get the download URL
        imageUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _imageUrlController.text = imageUrl!;
          _isUploading = false;
        });
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        _showErrorSnackBar('Error uploading image: $e');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Prepare product data
    final productData = {
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'unit': unit,
      'imageUrl': imageUrl,
      'categoryId': _selectedCategoryId,
      'isPopular': _isPopular,
      'isSpecialOffer': _isSpecialOffer,
      'iconCode': 0xe25e, // Default icon code
      'updatedAt': FieldValue.serverTimestamp(),
      'nameSearch': name.toLowerCase(), // For case-insensitive search
    };

    if (_isEditing && _currentProductId != null) {
      // Update existing product
      await productsRef.doc(_currentProductId).update(productData);
      _showSuccessSnackBar('Product updated successfully');
    } else {
      // Create new product
      productData['createdAt'] = FieldValue.serverTimestamp();
      await productsRef.add(productData);
      _showSuccessSnackBar('Product added successfully');
    }

    // Reset form and refresh product list
    _resetForm();
    await _loadProducts();

    // Switch to product list tab
    _tabController.animateTo(1);
  } catch (e) {
    _showErrorSnackBar('Error saving product: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Save category (create or update)
Future<void> _saveCategory() async {
  // Validate form
  if (!_categoryFormKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Parse form values
    final name = _categoryNameController.text.trim();
    final iconCode = int.tryParse(_categoryIconCodeController.text.trim().replaceAll('0x', ''), radix: 16) ?? 0xe25e;
    final color = _categoryColorController.text.trim();
    String? imageUrl = _categoryImageUrlController.text.trim();

    // Upload image if selected
    if (_categoryImageFile != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Create a unique filename
        final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = storageRef.child('category_images/$fileName');

        // Upload the file to Firebase Storage
        final uploadTask = ref.putFile(_categoryImageFile!);
        final TaskSnapshot snapshot = await uploadTask;

        // Get the download URL
        imageUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _categoryImageUrlController.text = imageUrl!;
          _isUploading = false;
        });
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        _showErrorSnackBar('Error uploading image: $e');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Prepare category data
    final categoryData = {
      'name': name,
      'iconCode': iconCode,
      'color': color,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_isEditingCategory && _currentCategoryId != null) {
      // Update existing category
      await categoriesRef.doc(_currentCategoryId).update(categoryData);
      _showSuccessSnackBar('Category updated successfully');
    } else {
      // Create new category
      categoryData['createdAt'] = FieldValue.serverTimestamp();
      await categoriesRef.add(categoryData);
      _showSuccessSnackBar('Category added successfully');
    }

    // Reset form and refresh category list
    _resetCategoryForm();
    await _loadCategories();
  } catch (e) {
    _showErrorSnackBar('Error saving category: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Pick image from gallery or camera
Future<void> _pickImage(ImageSource source, {bool forOffer = false, bool forCategory = false}) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        if (forCategory) {
          _categoryImageFile = File(pickedFile.path);
          // Clear any existing URL since we'll upload a new image
          _categoryImageUrlController.text = '';
        } else if (forOffer) {
          _imageFile = File(pickedFile.path);
          // Clear any existing URL since we'll upload a new image
          _imageUrlController.text = '';
        } else {
          _imageFile = File(pickedFile.path);
          // Clear any existing URL since we'll upload a new image
          _imageUrlController.text = '';
        }
      });
    }
  } catch (e) {
    _showErrorSnackBar('Error picking image: $e');
  }
}

// Show image picker options
void _showImagePickerOptions({bool forOffer = false, bool forCategory = false}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF1E88E5),
                ),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Select from your photo library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, forOffer: forOffer, forCategory: forCategory);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF1E88E5),
                ),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a new photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, forOffer: forOffer, forCategory: forCategory);
              },
            ),
            if ((forCategory && (_categoryImageUrlController.text.isNotEmpty || _categoryImageFile != null)) ||
                (forOffer && (_imageUrlController.text.isNotEmpty || _imageFile != null)) ||
                (!forOffer && !forCategory && (_imageUrlController.text.isNotEmpty || _imageFile != null)))
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete, color: errorColor),
                ),
                title: Text(
                  'Remove Image',
                  style: TextStyle(color: errorColor),
                ),
                subtitle: const Text('Clear the current image'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (forCategory) {
                      _categoryImageFile = null;
                      _categoryImageUrlController.clear();
                    } else if (forOffer) {
                      _imageFile = null;
                      _imageUrlController.clear();
                    } else {
                      _imageFile = null;
                      _imageUrlController.clear();
                    }
                  });
                },
              ),
          ],
        ),
      ),
    ),
  );
}

  // Preview image in a dialog
  void _previewImage(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Image Preview'),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder:
                        (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: errorColor, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: errorColor),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error.toString(),
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Copy image URL to clipboard
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy URL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
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

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Validate URL
  bool _isValidUrl(String url) {
    if (url.isEmpty) return true; // Empty URLs are allowed

    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Build the product form
  Widget _buildProductForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isEditing ? Icons.edit : Icons.add_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Product' : 'Add New Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _resetForm,
                    tooltip: 'Cancel Editing',
                  ),
              ],
            ),
          ),

          // Form fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'Enter product name',
                    prefixIcon: const Icon(Icons.shopping_bag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a product name';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Price and Original Price (side by side)
                Row(
                  children: [
                    // Price
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price (₹) *',
                          hintText: 'Enter price',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a price';
                          }
                          try {
                            final price = double.parse(value);
                            if (price < 0) {
                              return 'Price cannot be negative';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Original Price
                    Expanded(
                      child: TextFormField(
                        controller: _originalPriceController,
                        decoration: InputDecoration(
                          labelText: 'Original Price (₹)',
                          hintText: 'Enter original price',
                          prefixIcon: const Icon(Icons.money_off),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            try {
                              final originalPrice = double.parse(value);
                              if (originalPrice < 0) {
                                return 'Cannot be negative';
                              }

                              final price =
                                  double.tryParse(_priceController.text) ?? 0;
                              if (originalPrice < price) {
                                return 'Must be ≥ price';
                              }
                            } catch (e) {
                              return 'Enter valid number';
                            }
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Discount and Unit (side by side)
                Row(
                  children: [
                    // Discount Percentage
                    Expanded(
                      child: TextFormField(
                ))],
                ),
                const SizedBox(height: 16),

                // Discount and Unit (side by side)
                Row(
                  children: [
                    // Discount Percentage
                    Expanded(
                      child: TextFormField(
                        controller: _discountPercentageController,
                        decoration: InputDecoration(
                          labelText: 'Discount (%)',
                          hintText: 'Enter discount',
                          prefixIcon: const Icon(Icons.discount),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            try {
                              final discount = double.parse(value);
                              if (discount < 0) {
                                return 'Cannot be negative';
                              }
                              if (discount > 100) {
                                return 'Cannot exceed 100%';
                              }
                            } catch (e) {
                              return 'Enter valid number';
                            }
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Unit
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          labelText: 'Unit *',
                          hintText: 'e.g., kg, piece, dozen',
                          prefixIcon: const Icon(Icons.straighten),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a unit';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    hintText: 'Select a category',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  items:
                      _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'],
                          child: Text(category['name']),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Image URL with preview
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'Enter image URL or upload an image',
                        prefixIcon: const Icon(Icons.image),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Preview button
                            if (_imageUrlController.text.isNotEmpty &&
                                _isValidUrl(_imageUrlController.text))
                              IconButton(
                                icon: const Icon(Icons.preview),
                                onPressed:
                                    () =>
                                        _previewImage(_imageUrlController.text),
                                tooltip: 'Preview Image',
                              ),

                            // Upload button
                            IconButton(
                              icon: const Icon(Icons.upload),
                              onPressed: () => _showImagePickerOptions(),
                              tooltip: 'Upload Image',
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.trim().isNotEmpty &&
                            !_isValidUrl(value)) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Force rebuild to update preview
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    // Image preview
                    if (_imageFile != null ||
                        (_imageUrlController.text.isNotEmpty &&
                            _isValidUrl(_imageUrlController.text)))
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_imageFile != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _imageFile!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else if (_imageUrlController.text.isNotEmpty &&
                                _isValidUrl(_imageUrlController.text))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: _imageUrlController.text,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  placeholder:
                                      (context, url) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error, color: errorColor),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: TextStyle(color: errorColor),
                                          ),
                                        ],
                                      ),
                                ),
                              ),

                            // Remove image button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _imageFile = null;
                                      _imageUrlController.clear();
                                    });
                                  },
                                  tooltip: 'Remove Image',
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Product flags (Popular and Special Offer)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Is Popular checkbox
                      CheckboxListTile(
                        value: _isPopular,
                        onChanged: (value) {
                          setState(() {
                            _isPopular = value ?? false;
                          });
                        },
                        title: const Text('Mark as Popular'),
                        subtitle: const Text(
                          'Popular products appear on the home screen',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      // Divider between checkboxes
                      Divider(color: Colors.grey.shade300),

                      // Is Special Offer checkbox
                      CheckboxListTile(
                        value: _isSpecialOffer,
                        onChanged: (value) {
                          setState(() {
                            _isSpecialOffer = value ?? false;
                          });
                        },
                        title: const Text('Mark as Special Offer'),
                        subtitle: const Text(
                          'Special offers appear in the offers section',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _isUploading ? null : _saveProduct,
                    icon: Icon(_isEditing ? Icons.save : Icons.add),
                    label: Text(_isEditing ? 'Update Product' : 'Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                if (_isLoading || _isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isUploading
                                ? 'Uploading image...'
                                : 'Saving product...',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
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

// Build the category form
Widget _buildCategoryForm() {
  return Form(
    key: _categoryFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isEditingCategory ? Icons.edit : Icons.add_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                _isEditingCategory ? 'Edit Category' : 'Add New Category',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isEditingCategory)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _resetCategoryForm,
                  tooltip: 'Cancel Editing',
                ),
            ],
          ),
        ),

        // Form fields
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category name
              TextFormField(
                controller: _categoryNameController,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'Enter category name',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Icon Code and Color (side by side)
              Row(
                children: [
                  // Icon Code
                  Expanded(
                    child: TextFormField(
                      controller: _categoryIconCodeController,
                      decoration: InputDecoration(
                        labelText: 'Icon Code *',
                        hintText: 'e.g., 0xe25e',
                        prefixIcon: const Icon(Icons.emoji_symbols),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an icon code';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Color
                  Expanded(
                    child: TextFormField(
                      controller: _categoryColorController,
                      decoration: InputDecoration(
                        labelText: 'Color Code *',
                        hintText: 'e.g., 0xFF1E88E5',
                        prefixIcon: const Icon(Icons.color_lens),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a color code';
                        }
                        if (!value.startsWith('0xFF')) {
                          return 'Must start with 0xFF';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image URL with preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _categoryImageUrlController,
                    decoration: InputDecoration(
                      labelText: 'Image URL *',
                      hintText: 'Enter image URL or upload an image',
                      prefixIcon: const Icon(Icons.image),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Preview button
                          if (_categoryImageUrlController.text.isNotEmpty &&
                              _isValidUrl(_categoryImageUrlController.text))
                            IconButton(
                              icon: const Icon(Icons.preview),
                              onPressed: () => _previewImage(_categoryImageUrlController.text),
                              tooltip: 'Preview Image',
                            ),

                          // Upload button
                          IconButton(
                            icon: const Icon(Icons.upload),
                            onPressed: () => _showImagePickerOptions(forOffer: false, forCategory: true),
                            tooltip: 'Upload Image',
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an image URL';
                      }
                      if (!_isValidUrl(value)) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Force rebuild to update preview
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),

                  // Image preview
                  if (_categoryImageFile != null ||
                      (_categoryImageUrlController.text.isNotEmpty &&
                          _isValidUrl(_categoryImageUrlController.text)))
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_categoryImageFile != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _categoryImageFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            )
                          else if (_categoryImageUrlController.text.isNotEmpty &&
                              _isValidUrl(_categoryImageUrlController.text))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: _categoryImageUrlController.text,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: errorColor),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(color: errorColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Remove image button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _categoryImageFile = null;
                                    _categoryImageUrlController.clear();
                                  });
                                },
                                tooltip: 'Remove Image',
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _isUploading ? null : _saveCategory,
                  icon: Icon(_isEditingCategory ? Icons.save : Icons.add),
                  label: Text(_isEditingCategory ? 'Update Category' : 'Add Category'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              if (_isLoading || _isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isUploading
                              ? 'Uploading image...'
                              : 'Saving category...',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

// Build category list item
Widget _buildCategoryItem(Map<String, dynamic> category) {
  final Color categoryColor = Color(int.parse(category['color']));
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ],
    ),
    child: Column(
      children: [
        // Category header with image
        Row(
          children: [
            // Category image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: category['imageUrl'] != null && category['imageUrl'].isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: category['imageUrl'],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 120,
                        color: categoryColor.withOpacity(0.1),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              categoryColor,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 120,
                        color: categoryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: categoryColor,
                        ),
                      ),
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: categoryColor.withOpacity(0.1),
                      child: Icon(
                        IconData(
                          int.tryParse(category['iconCode']?.toString() ?? '', radix: 16) ?? 0xe25e,
                          fontFamily: 'MaterialIcons',
                        ),
                        color: categoryColor,
                        size: 40,
                      ),
                    ),
            ),

            // Category details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.palette,
                            size: 16,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category['color'],
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<QuerySnapshot>(
                      future: productsRef.where('categoryId', isEqualTo: category['id']).get(),
                      builder: (context, snapshot) {
                        int productCount = 0;
                        if (snapshot.hasData) {
                          productCount = snapshot.data!.docs.length;
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_bag,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$productCount products',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Preview image button
              if (category['imageUrl'] != null && category['imageUrl'].isNotEmpty)
                TextButton.icon(
                  onPressed: () => _previewImage(category['imageUrl']),
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('View Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),

              // Edit button
              TextButton.icon(
                onPressed: () => _editCategory(category),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),

              // Delete button
              TextButton.icon(
                onPressed: () => _deleteCategory(category['id']),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: errorColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // Build product list item
  Widget _buildProductItem(GroceryItem product) {
    // Find category name
    final categoryName =
        _categories.firstWhere(
          (category) => category['id'] == product.categoryId,
          orElse: () => {'name': 'Uncategorized'},
        )['name'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          // Product header with image
          Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child:
                    product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                width: 120,
                                height: 120,
                                color: primaryColor.withOpacity(0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 120,
                                height: 120,
                                color: primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: primaryColor,
                                ),
                              ),
                        )
                        : Container(
                          width: 120,
                          height: 120,
                          color: primaryColor.withOpacity(0.1),
                          child: Icon(
                            product.icon,
                            color: primaryColor,
                            size: 40,
                          ),
                        ),
              ),

              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Product badges
                          Row(
                            children: [
                              if (product.isPopular)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.shade400,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Popular',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (product.isSpecialOffer)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_offer,
                                        size: 14,
                                        color: Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Special Offer',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.unit,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (product.discountPercentage > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹${product.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Preview image button
                if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _previewImage(product.imageUrl!),
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('View Image'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),

                // Edit button
                TextButton.icon(
                  onPressed: () => _editProduct(product),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),

                // Delete button
                TextButton.icon(
                  onPressed: () => _deleteProduct(product.id),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: errorColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build filter and sort controls
  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _applyFiltersAndSort();
                          });
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
            onChanged: (value) {
              setState(() {
                _applyFiltersAndSort();
              });
            },
          ),
          const SizedBox(height: 16),

          // Filter and sort controls
          Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterCategory,
                  decoration: InputDecoration(
                    labelText: 'Filter by Category',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                      child: Text('All Categories'),
                    ),
                    ..._categories.map((category) {
                      return DropdownMenuItem<String?>(
                        value: category['id'],
                        child: Text(category['name']),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterCategory = value;
                      _applyFiltersAndSort();
                    });
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
                      horizontal: 16,
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
                      value: 'name',
                      child: Text('Name'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'price',
                      child: Text('Price'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'discount',
                      child: Text('Discount'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                      _applyFiltersAndSort();
                    });
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
                    _applyFiltersAndSort();
                  });
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

          // Filter chips
          if (_searchController.text.isNotEmpty || _filterCategory != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_searchController.text.isNotEmpty)
                    Chip(
                      label: Text('Search: ${_searchController.text}'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _searchController.clear();
                          _applyFiltersAndSort();
                        });
                      },
                      backgroundColor: primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: primaryColor),
                    ),

                  if (_filterCategory != null)
                    Chip(
                      label: Text(
                        'Category: ${_categories.firstWhere((c) => c['id'] == _filterCategory)['name']}',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _filterCategory = null;
                          _applyFiltersAndSort();
                        });
                      },
                      backgroundColor: primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: primaryColor),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Load settings from Firestore
  Future<void> _loadSettings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingSettings = true;
    });
    
    try {
      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('app_settings').get();
      
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null) {
          setState(() {
            _deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 40.0;
            _taxRate = (data['taxRate'] as num?)?.toDouble() ?? 5.0;
            
            _deliveryFeeController.text = _deliveryFee.toString();
            _taxRateController.text = _taxRate.toString();
          });
        }
      } else {
        // Create default settings if they don't exist
        await FirebaseFirestore.instance.collection('settings').doc('app_settings').set({
          'deliveryFee': _deliveryFee,
          'taxRate': _taxRate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _deliveryFeeController.text = _deliveryFee.toString();
        _taxRateController.text = _taxRate.toString();
      }
    } catch (e) {
      print('Error loading settings: $e');
      _showErrorSnackBar('Error loading settings: $e');
      
      // Set default values in controllers
      _deliveryFeeController.text = _deliveryFee.toString();
      _taxRateController.text = _taxRate.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
        });
      }
    }
  }
  
  // Save settings to Firestore
  Future<void> _saveSettings() async {
    if (!_settingsFormKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isUpdatingSettings = true;
    });
    
    try {
      final deliveryFee = double.parse(_deliveryFeeController.text.trim());
      final taxRate = double.parse(_taxRateController.text.trim());
      
      await FirebaseFirestore.instance.collection('settings').doc('app_settings').update({
        'deliveryFee': deliveryFee,
        'taxRate': taxRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _deliveryFee = deliveryFee;
        _taxRate = taxRate;
      });
      
      _showSuccessSnackBar('Settings updated successfully');
    } catch (e) {
      print('Error saving settings: $e');
      _showErrorSnackBar('Error saving settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingSettings = false;
        });
      }
    }
  }
  
  // Build the settings tab
  Widget _buildSettingsTab() {
    return Form(
      key: _settingsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
                  'App Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Settings form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: _isLoadingSettings
                ? Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading settings...',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery Fee
                      const Text(
                        'Delivery Fee Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deliveryFeeController,
                        decoration: InputDecoration(
                          labelText: 'Delivery Fee (₹) *',
                          hintText: 'Enter delivery fee',
                          prefixIcon: const Icon(Icons.delivery_dining),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter delivery fee';
                          }
                          try {
                            final fee = double.parse(value);
                            if (fee < 0) {
                              return 'Fee cannot be negative';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is the base delivery fee charged to customers. Set to 0 for free delivery.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Tax Rate
                      const Text(
                        'Tax Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _taxRateController,
                        decoration: InputDecoration(
                          labelText: 'Tax Rate (%) *',
                          hintText: 'Enter tax rate percentage',
                          prefixIcon: const Icon(Icons.percent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter tax rate';
                          }
                          try {
                            final rate = double.parse(value);
                            if (rate < 0) {
                              return 'Rate cannot be negative';
                            }
                            if (rate > 100) {
                              return 'Rate cannot exceed 100%';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is the tax rate applied to all orders.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdatingSettings ? null : _saveSettings,
                          icon: Icon(_isUpdatingSettings ? Icons.hourglass_top : Icons.save),
                          label: Text(_isUpdatingSettings ? 'Updating...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      
                      if (_isUpdatingSettings)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Updating settings...',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          
          // Order Management Section
          const SizedBox(height: 32),
          _buildOrderManagementSection(),
        ],
      ),
    );
  }
  
  // Build the order management section
  Widget _buildOrderManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order management header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_bag,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'Order Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Order management content
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminOrdersScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('View All Orders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage all customer orders, update order status, and track deliveries.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Product Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProducts();
              _loadCategories();
            },
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Add/Edit Product'),
            Tab(icon: Icon(Icons.list), text: 'Products'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Add/Edit Product Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildProductForm(),
          ),

          // Product List Tab
          _isLoading && _products.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading products...',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadProducts,
                color: primaryColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product list header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Product List',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_filteredProducts.length} products',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Filter controls
                      _buildFilterControls(),
                      const SizedBox(height: 16),

                      // Product list
                      if (_filteredProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                offset: const Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
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
                                  _searchController.text.isNotEmpty ||
                                          _filterCategory != null
                                      ? 'No products match your filters'
                                      : 'No products available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                if (_searchController.text.isNotEmpty ||
                                    _filterCategory != null)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _filterCategory = null;
                                        _applyFiltersAndSort();
                                      });
                                    },
                                    icon: const Icon(Icons.filter_alt_off),
                                    label: const Text('Clear Filters'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                if (_products.isEmpty &&
                                    _searchController.text.isEmpty &&
                                    _filterCategory == null)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _tabController.animateTo(0);
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Your First Product'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            return _buildProductItem(_filteredProducts[index]);
                          },
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

          // Categories Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category form
                _buildCategoryForm(),
                const SizedBox(height: 24),

                // Categories list header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_categories.length} categories',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Categories list
                if (_isLoading && _categories.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading categories...',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_categories.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Add your first category using the form above',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      return _buildCategoryItem(_categories[index]);
                    },
                  ),
              ],
            ),
          ),
          
          // Settings Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSettingsTab(),
          ),
        ],
      ),
      floatingActionButton:
          _tabController.index == 1
              ? FloatingActionButton(
                onPressed: () {
                  _resetForm();
                  _tabController.animateTo(0);
                },
                backgroundColor: primaryColor,
                child: const Icon(Icons.add),
                tooltip: 'Add New Product',
              )
              : null,
    );
  }
}
