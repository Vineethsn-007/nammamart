import 'package:flutter/material.dart';

class GroceryCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String? imageUrl; // Add imageUrl property

  GroceryCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.imageUrl, // Make it optional
  });

  // Create a GroceryCategory from a Firestore document
  factory GroceryCategory.fromFirestore(String docId, Map<String, dynamic> data) {
    return GroceryCategory(
      id: docId,
      name: data['name'] ?? '',
      icon: IconData(data['iconCode'] ?? 0xe25a, fontFamily: 'MaterialIcons'),
      color: Color(int.parse(data['color'] ?? '0xFF000000')),
      imageUrl: data['imageUrl'], // Add imageUrl support
    );
  }

  // Convert to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCode': icon.codePoint,
      'color': color.value.toString(),
      'imageUrl': imageUrl, // Include imageUrl in the map
    };
  }
}