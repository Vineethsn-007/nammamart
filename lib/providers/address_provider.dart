import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address.dart';

class AddressProvider with ChangeNotifier {
  static const String ADDRESSES_KEY = 'user_addresses';
  static const String SELECTED_ADDRESS_KEY = 'selected_address_id';
  static const String LEGACY_ADDRESS_KEY = 'address';

  List<Address> _addresses = [];
  Address? _selectedAddress;

  List<Address> get addresses => _addresses;
  Address? get selectedAddress => _selectedAddress;

  AddressProvider() {
    _loadAddresses();
  }

  // Load addresses from SharedPreferences
  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for legacy single address format
      final legacyAddress = prefs.getString(LEGACY_ADDRESS_KEY);
      
      // Check for new multiple address format
      final addressesJson = prefs.getString(ADDRESSES_KEY);
      final selectedAddressId = prefs.getString(SELECTED_ADDRESS_KEY);
      
      // If we have addresses in the new format
      if (addressesJson != null) {
        final List<dynamic> decodedList = jsonDecode(addressesJson);
        _addresses = decodedList
            .map((item) => Address.fromMap(Map<String, dynamic>.from(item)))
            .toList();
            
        // Set selected address if available
        if (selectedAddressId != null && _addresses.isNotEmpty) {
          _selectedAddress = _addresses.firstWhere(
            (address) => address.id == selectedAddressId,
            orElse: () => _addresses.firstWhere(
              (address) => address.isDefault,
              orElse: () => _addresses.first,
            ),
          );
        } else if (_addresses.isNotEmpty) {
          // Find default address or use the first one
          _selectedAddress = _addresses.firstWhere(
            (address) => address.isDefault,
            orElse: () => _addresses.first,
          );
        }
      }
      // If we have a legacy address but no addresses in the new format
      else if (legacyAddress != null && legacyAddress.isNotEmpty) {
        // Migrate legacy address to new format
        final newAddress = Address(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullAddress: legacyAddress,
          label: 'Home',
          isDefault: true,
        );
        
        _addresses = [newAddress];
        _selectedAddress = newAddress;
        
        // Save the migrated address in the new format
        await _saveAddresses();
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading addresses: $e');
    }
  }

  // Save addresses to SharedPreferences
  Future<void> _saveAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final List<Map<String, dynamic>> encodedList = 
          _addresses.map((address) => address.toMap()).toList();
          
      await prefs.setString(ADDRESSES_KEY, jsonEncode(encodedList));
      
      if (_selectedAddress != null) {
        await prefs.setString(SELECTED_ADDRESS_KEY, _selectedAddress!.id);
      }
    } catch (e) {
      print('Error saving addresses: $e');
    }
  }

  // Add a new address
  Future<void> addAddress(Address address) async {
    // If this is the first address, make it default
    final bool makeDefault = _addresses.isEmpty;
    
    final newAddress = address.copyWith(
      isDefault: makeDefault,
    );
    
    _addresses.add(newAddress);
    
    // If this is the first address or it's marked as default, select it
    if (makeDefault || newAddress.isDefault) {
      _selectedAddress = newAddress;
    }
    
    await _saveAddresses();
    notifyListeners();
  }

  // Update an existing address
  Future<void> updateAddress(Address updatedAddress) async {
    final index = _addresses.indexWhere((address) => address.id == updatedAddress.id);
    
    if (index >= 0) {
      _addresses[index] = updatedAddress;
      
      // If the updated address was selected, update the selected address
      if (_selectedAddress?.id == updatedAddress.id) {
        _selectedAddress = updatedAddress;
      }
      
      // If this address is now the default, update other addresses
      if (updatedAddress.isDefault) {
        for (int i = 0; i < _addresses.length; i++) {
          if (i != index && _addresses[i].isDefault) {
            _addresses[i] = _addresses[i].copyWith(isDefault: false);
          }
        }
      }
      
      await _saveAddresses();
      notifyListeners();
    }
  }

  // Remove an address
  Future<void> removeAddress(String addressId) async {
    _addresses.removeWhere((address) => address.id == addressId);
    
    // If the removed address was selected, select a new one
    if (_selectedAddress?.id == addressId) {
      _selectedAddress = _addresses.isNotEmpty ? _addresses.firstWhere(
        (address) => address.isDefault,
        orElse: () => _addresses.first,
      ) : null;
    }
    
    await _saveAddresses();
    notifyListeners();
  }

  // Select an address
  Future<void> selectAddress(String addressId) async {
    final address = _addresses.firstWhere(
      (address) => address.id == addressId,
      orElse: () => throw Exception('Address not found'),
    );
    
    _selectedAddress = address;
    await _saveAddresses();
    notifyListeners();
  }

  // Set an address as default
  Future<void> setDefaultAddress(String addressId) async {
    for (int i = 0; i < _addresses.length; i++) {
      if (_addresses[i].id == addressId) {
        _addresses[i] = _addresses[i].copyWith(isDefault: true);
        _selectedAddress = _addresses[i];
      } else if (_addresses[i].isDefault) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
    
    await _saveAddresses();
    notifyListeners();
  }
  
  // Import legacy address
  Future<void> importLegacyAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyAddress = prefs.getString(LEGACY_ADDRESS_KEY);
      
      if (legacyAddress != null && legacyAddress.isNotEmpty && _addresses.isEmpty) {
        // Create a new address from the legacy one
        final newAddress = Address(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullAddress: legacyAddress,
          label: 'Home',
          isDefault: true,
        );
        
        _addresses = [newAddress];
        _selectedAddress = newAddress;
        
        // Save in the new format
        await _saveAddresses();
        notifyListeners();
      }
    } catch (e) {
      print('Error importing legacy address: $e');
    }
  }
  
  // Convert and add address
  Future<void> convertAndAddAddress(
    String fullAddress, {
    double? latitude,
    double? longitude,
    bool setAsDefault = false,
  }) async {
    if (fullAddress.isEmpty) return;
    
    // Check if this address already exists
    final existingAddress = _addresses.firstWhere(
      (address) => address.fullAddress.toLowerCase() == fullAddress.toLowerCase(),
      // ignore: cast_from_null_always_fails
      orElse: () => null as Address,
    );
    
    // ignore: unnecessary_null_comparison
    if (existingAddress != null) {
      // If it exists, just select it
      await selectAddress(existingAddress.id);
      return;
    }
    
    // Create a new address
    final newAddress = Address(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullAddress: fullAddress,
      label: 'Home',
      isDefault: setAsDefault || _addresses.isEmpty,
      latitude: latitude,
      longitude: longitude,
    );
    
    await addAddress(newAddress);
  }
}