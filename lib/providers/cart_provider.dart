import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grocery_item.dart';

class CartProvider extends ChangeNotifier {
  final List<String> _cartItemIds = [];
  final Map<String, int> _itemQuantities = {};
  final productsRef = FirebaseFirestore.instance.collection('products');
  final settingsRef = FirebaseFirestore.instance.collection('settings');

  // Settings for delivery fee and tax
  double _deliveryFeeBase = 40.0;
  double _deliveryFeeThreshold = 500.0;
  double _taxRate = 5.0;
  bool _settingsLoaded = false;

  List<String> get cartItemIds => _cartItemIds;
  Map<String, int> get itemQuantities => _itemQuantities;

  // Getters for settings
  double get deliveryFeeBase => _deliveryFeeBase;
  double get deliveryFeeThreshold => _deliveryFeeThreshold;
  double get taxRate => _taxRate;

  CartProvider() {
    _loadCartFromPrefs();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsDoc = await settingsRef.doc('app_settings').get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null) {
          _deliveryFeeBase =
              (data['deliveryFeeBase'] as num?)?.toDouble() ?? 40.0;
          _deliveryFeeThreshold =
              (data['deliveryFeeThreshold'] as num?)?.toDouble() ?? 500.0;
          _taxRate = (data['taxRate'] as num?)?.toDouble() ?? 5.0;
          _settingsLoaded = true;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading settings in cart provider: $e');
    }
  }

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartItems = prefs.getStringList('cartItems') ?? [];

      _cartItemIds.clear();
      _cartItemIds.addAll(cartItems);

      // Load quantities
      for (var itemId in _cartItemIds) {
        final quantity = prefs.getInt('quantity_$itemId') ?? 1;
        _itemQuantities[itemId] = quantity;
      }

      notifyListeners();
    } catch (e) {
      print('Error loading cart from prefs: $e');
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cartItems', _cartItemIds);

      // Save quantities
      for (var entry in _itemQuantities.entries) {
        await prefs.setInt('quantity_${entry.key}', entry.value);
      }
    } catch (e) {
      print('Error saving cart to prefs: $e');
    }
  }

  void addToCart(String productId) {
    if (!_cartItemIds.contains(productId)) {
      _cartItemIds.add(productId);
      _itemQuantities[productId] = 1;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    _cartItemIds.remove(productId);
    _itemQuantities.remove(productId);
    _saveCartToPrefs();
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity > 0) {
      _itemQuantities[productId] = quantity;
      _saveCartToPrefs();
      notifyListeners();
    } else {
      removeFromCart(productId);
    }
  }

  void clearCart() {
    _cartItemIds.clear();
    _itemQuantities.clear();
    _saveCartToPrefs();
    notifyListeners();
  }

  Future<List<GroceryItem>> fetchCartItems() async {
    if (_cartItemIds.isEmpty) return [];

    final List<GroceryItem> items = [];

    // Fetch items in batches to avoid large queries
    const batchSize = 10;
    for (var i = 0; i < _cartItemIds.length; i += batchSize) {
      final end = (i + batchSize < _cartItemIds.length)
          ? i + batchSize
          : _cartItemIds.length;
      final batch = _cartItemIds.sublist(i, end);

      try {
        final querySnapshot =
            await productsRef.where(FieldPath.documentId, whereIn: batch).get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          items.add(GroceryItem(
            id: doc.id,
            name: data['name'] ?? '',
            price: (data['price'] as num?)?.toDouble() ?? 0.0,
            originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0.0,
            discountPercentage:
                (data['discountPercentage'] as num?)?.toDouble() ?? 0.0,
            unit: data['unit'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            categoryId: data['categoryId'] ?? '',
            isPopular: data['isPopular'] ?? false,
            isSpecialOffer: data['isSpecialOffer'] ?? false,
            icon: IconData(
              data['iconCode'] ?? 0xe25e,
              fontFamily: 'MaterialIcons',
            ),
          ));
        }
      } catch (e) {
        print('Error fetching items batch: $e');
      }
    }

    return items;
  }

  double calculateSubtotal(List<GroceryItem> items) {
    double subtotal = 0;
    for (var item in items) {
      subtotal += item.price * (_itemQuantities[item.id] ?? 1);
    }
    return subtotal;
  }

  double calculateDeliveryFee(List<GroceryItem> items) {
    double totalDeliveryFee = 0;
    for (var item in items) {
      final quantity = _itemQuantities[item.id] ?? 1;
      if (item.deliveryFee != null) {
        totalDeliveryFee += item.deliveryFee! * quantity;
      } else {
        // Fallback to global logic
        totalDeliveryFee += (calculateSubtotal([item]) >= _deliveryFeeThreshold
                ? 0
                : _deliveryFeeBase) *
            quantity;
      }
    }
    return totalDeliveryFee;
  }

  double calculateTax(List<GroceryItem> items) {
    double totalTax = 0;
    for (var item in items) {
      final quantity = _itemQuantities[item.id] ?? 1;
      final subtotal = item.price * quantity;
      if (item.gst != null) {
        totalTax += subtotal * (item.gst! / 100);
      } else {
        // Fallback to global logic
        totalTax += subtotal * (_taxRate / 100);
      }
    }
    return totalTax;
  }

  double calculateTotal(List<GroceryItem> items) {
    final subtotal = calculateSubtotal(items);
    final deliveryFee = calculateDeliveryFee(items);
    final tax = calculateTax(items);
    return subtotal + deliveryFee + tax;
  }
}
