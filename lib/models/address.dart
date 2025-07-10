class Address {
  final String id;
  final String fullAddress;
  final String label; // e.g., "Home", "Work", "Other"
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Address({
    required this.id,
    required this.fullAddress,
    required this.label,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  Address copyWith({
    String? id,
    String? fullAddress,
    String? label,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      fullAddress: fullAddress ?? this.fullAddress,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  // Convert Address object to a Map for SharedPreferences storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullAddress': fullAddress,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
    };
  }

  // Create an Address object from a map (from SharedPreferences)
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'],
      fullAddress: map['fullAddress'],
      label: map['label'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      isDefault: map['isDefault'] ?? false,
    );
  }
}
