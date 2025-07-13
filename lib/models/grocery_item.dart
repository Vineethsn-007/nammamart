import 'package:flutter/widgets.dart';

class GroceryItem {
  final String id;
  final String name;
  final double price;
  final double originalPrice;
  final double discountPercentage;
  final String unit;
  final String? imageUrl;
  final IconData? icon; // Made optional since it's not stored in Firestore
  final String categoryId;
  final bool isPopular;
  final bool isSpecialOffer; // Added special offer flag
  final double? deliveryFee; // Add this
  final double? gst; // Add this

  GroceryItem({
    required this.id,
    required this.name,
    required this.price,
    required this.originalPrice,
    this.discountPercentage = 0.0,
    required this.unit,
    this.imageUrl,
    this.icon, // Made optional
    required this.categoryId,
    this.isPopular = false,
    this.isSpecialOffer = false, // Default to false
    this.deliveryFee,
    this.gst,
  });

  // Create a GroceryItem from Firestore document
  factory GroceryItem.fromFirestore(String docId, Map<String, dynamic> data) {
    return GroceryItem(
      id: docId,
      name: data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0.0,
      // Fixed to properly handle both int and double types from Firestore
      discountPercentage: (data['discountPercentage'] is int)
          ? (data['discountPercentage'] as int).toDouble()
          : (data['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] ?? '',
      categoryId: data['categoryId'] ?? '',
      imageUrl: data['imageUrl'],
      isPopular: data['isPopular'] ?? false,
      isSpecialOffer: data['isSpecialOffer'] ?? false, // Read from Firestore
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
      gst: (data['gst'] as num?)?.toDouble(),
      // Icon is not stored in Firestore, so we don't set it here
      // The UI can set appropriate icons based on category or other logic
    );
  }

  // Convert to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'unit': unit,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'isPopular': isPopular,
      'isSpecialOffer': isSpecialOffer, // Store in Firestore
      'deliveryFee': deliveryFee,
      'gst': gst,
      // We don't store icon in Firestore as it's a UI element
    };
  }

  // Calculate the amount saved
  double get savedAmount => originalPrice - price;

  // Check if the item is on discount
  bool get isOnDiscount => discountPercentage > 0;

  // Create a copy of this GroceryItem with modified properties
  GroceryItem copyWith({
    String? id,
    String? name,
    double? price,
    double? originalPrice,
    double? discountPercentage,
    String? unit,
    String? imageUrl,
    IconData? icon,
    String? categoryId,
    bool? isPopular,
    bool? isSpecialOffer,
    double? deliveryFee,
    double? gst,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      categoryId: categoryId ?? this.categoryId,
      isPopular: isPopular ?? this.isPopular,
      isSpecialOffer:
          isSpecialOffer ?? this.isSpecialOffer, // Added to copyWith
      deliveryFee: deliveryFee ?? this.deliveryFee,
      gst: gst ?? this.gst,
    );
  }
}
