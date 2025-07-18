import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grocery_item.dart';
import 'package:hive/hive.dart';

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
  bool _useCustomDeliveryFee = true;

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
      final settingsBox = Hive.box('settingsBox');
      final cachedSettings = settingsBox.get('app_settings');
      if (cachedSettings != null && cachedSettings is Map) {
        _deliveryFeeBase =
            (cachedSettings['deliveryFeeBase'] as num?)?.toDouble() ?? 40.0;
        _deliveryFeeThreshold =
            (cachedSettings['deliveryFeeThreshold'] as num?)?.toDouble() ??
                500.0;
        _taxRate = (cachedSettings['taxRate'] as num?)?.toDouble() ?? 5.0;
        _useCustomDeliveryFee = cachedSettings['useCustomDeliveryFee'] ?? true;
        _settingsLoaded = true;
        notifyListeners();
      } else {
        final settingsDoc = await settingsRef.doc('app_settings').get();
        if (settingsDoc.exists) {
          final data = settingsDoc.data();
          if (data != null) {
            _deliveryFeeBase =
                (data['deliveryFeeBase'] as num?)?.toDouble() ?? 40.0;
            _deliveryFeeThreshold =
                (data['deliveryFeeThreshold'] as num?)?.toDouble() ?? 500.0;
            _taxRate = (data['taxRate'] as num?)?.toDouble() ?? 5.0;
            _useCustomDeliveryFee = data['useCustomDeliveryFee'] ?? true;
            _settingsLoaded = true;
            // Cache settings in Hive
            await settingsBox.put('app_settings', data);
            notifyListeners();
          }
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
    final productsBox = Hive.box('productsBox');
    List<String> idsToFetch = [];
    // Try to get products from cache first
    for (var id in _cartItemIds) {
      final cached = productsBox.get(id);
      if (cached != null && cached is GroceryItem) {
        items.add(cached);
      } else {
        idsToFetch.add(id);
      }
    }

    // Fetch items in batches to avoid large queries
    const batchSize = 10;
    for (var i = 0; i < idsToFetch.length; i += batchSize) {
      final end = (i + batchSize < idsToFetch.length)
          ? i + batchSize
          : idsToFetch.length;
      final batch = idsToFetch.sublist(i, end);

      try {
        final querySnapshot =
            await productsRef.where(FieldPath.documentId, whereIn: batch).get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final item = GroceryItem.fromFirestore(doc.id, data);
          items.add(item);
          // Cache in Hive
          await productsBox.put(doc.id, item);
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

  // Delivery fee calculation: respects the toggle
  // If useCustomDeliveryFee is false (free delivery ON), always return 0
  // If true, use per-item deliveryFee or fallback
  double calculateDeliveryFee(List<GroceryItem> items) {
    if (!_useCustomDeliveryFee) {
      // Free delivery for all orders
      return 0;
    }
    // Only charge the base delivery fee once per order
    return _deliveryFeeBase;
  }

  // Tax calculation: always per product, no fallback
  double calculateTax(List<GroceryItem> items) {
    double totalTax = 0;
    for (var item in items) {
      final quantity = _itemQuantities[item.id] ?? 1;
      final subtotal = item.price * quantity;
      if (item.gst != null) {
        totalTax += subtotal * (item.gst! / 100);
      } else {
        // No GST set, no tax
        totalTax += 0;
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

  // Public method to reload settings from Firestore
  void reloadSettings() {
    _loadSettings();
  }
}
