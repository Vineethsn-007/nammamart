import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../models/address.dart';
import '../providers/address_provider.dart';
import '../providers/theme_provider.dart';

class AddressSelectionDialog extends StatefulWidget {
  final Function(Address) onAddressSelect;
  
  const AddressSelectionDialog({
    Key? key,
    required this.onAddressSelect,
  }) : super(key: key);

  @override
  _AddressSelectionDialogState createState() => _AddressSelectionDialogState();
}

class _AddressSelectionDialogState extends State<AddressSelectionDialog> {
  bool _isLoadingCurrentLocation = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final addressProvider = Provider.of<AddressProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode
                ? Colors.black26
                : Colors.grey.shade200,
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
              const Text(
                'Select Delivery Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Saved addresses list
          addressProvider.addresses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No saved addresses yet',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: addressProvider.addresses.length,
                  itemBuilder: (context, index) {
                    final address = addressProvider.addresses[index];
                    final isSelected = addressProvider.selectedAddress?.id == address.id;
                    
                    return _buildAddressItem(
                      context,
                      address, 
                      isSelected,
                      () {
                        // Select this address
                        addressProvider.selectAddress(address.id);
                        widget.onAddressSelect(address); // Add this line to call the callback
                        Navigator.pop(context);
                      },
                      () => _showAddressFormDialog(context, address),
                      () async {
                        // Show delete confirmation
                        final shouldDelete = await _showDeleteConfirmationDialog(context);
                        if (shouldDelete) {
                          addressProvider.removeAddress(address.id);
                        }
                      },
                    );
                  },
                ),
                
          const SizedBox(height: 20),
          
          // Add new address options
          Text(
            'Add New Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          
          // Use current location option
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: _isLoadingCurrentLocation
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: primaryColor,
                    ),
            ),
            title: Text(
              'Use Current Location',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Get your address from GPS',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            onTap: _isLoadingCurrentLocation
                ? null
                : () => _getCurrentLocationAddress(context),
          ),
          
          // Enter manually option
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_location_alt,
                color: primaryColor,
              ),
            ),
            title: Text(
              'Enter Manually',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Type your delivery address',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            onTap: () => _showAddressFormDialog(context, null),
          ),
        ],
      ),
    );
  }

  // Build an individual address item in the list
  Widget _buildAddressItem(
    BuildContext context,
    Address address, 
    bool isSelected,
    VoidCallback onSelect,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? primaryColor.withOpacity(0.1) 
            : themeProvider.isDarkMode
                ? Colors.grey.shade800.withOpacity(0.3)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? primaryColor 
              : themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      address.label,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address.fullAddress,
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: primaryColor,
                    ),
                    label: Text(
                      'Edit',
                      style: TextStyle(
                        color: primaryColor,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Delete button
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    label: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red.shade600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog to confirm address deletion
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text(
          'Are you sure you want to delete this address?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  // Show dialog to add or edit an address
  void _showAddressFormDialog(BuildContext context, Address? addressToEdit) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final addressProvider = Provider.of<AddressProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
        
    final isEditing = addressToEdit != null;
    
    // Form controllers
    final addressController = TextEditingController(
      text: isEditing ? addressToEdit.fullAddress : '',
    );
    
    // Default label is Home for new addresses
    String selectedLabel = isEditing ? addressToEdit.label : 'Home';
    bool isDefault = isEditing ? addressToEdit.isDefault : false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Address' : 'Add New Address',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Address input field
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Full Address',
                      hintText: 'Enter your full address',
                      prefixIcon: Icon(Icons.location_on, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  
                  // Address label selection
                  Text(
                    'Address Label',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildLabelOption(
                        'Home', 
                        selectedLabel == 'Home', 
                        primaryColor,
                        () => setState(() => selectedLabel = 'Home'),
                      ),
                      const SizedBox(width: 10),
                      _buildLabelOption(
                        'Work', 
                        selectedLabel == 'Work', 
                        primaryColor,
                        () => setState(() => selectedLabel = 'Work'),
                      ),
                      const SizedBox(width: 10),
                      _buildLabelOption(
                        'Other', 
                        selectedLabel == 'Other', 
                        primaryColor,
                        () => setState(() => selectedLabel = 'Other'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Set as default option
                  Row(
                    children: [
                      Checkbox(
                        value: isDefault,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setState(() {
                            isDefault = value ?? false;
                          });
                        },
                      ),
                      const Text('Set as default address'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (addressController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your address'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        if (isEditing) {
                          // Update existing address
                          final updatedAddress = Address(
                            id: addressToEdit.id,
                            fullAddress: addressController.text.trim(),
                            label: selectedLabel,
                            latitude: addressToEdit.latitude,
                            longitude: addressToEdit.longitude,
                            isDefault: isDefault,
                          );
                          
                          addressProvider.updateAddress(updatedAddress);
                        } else {
                          // Add new address
                          final newAddress = Address(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            fullAddress: addressController.text.trim(),
                            label: selectedLabel,
                            isDefault: isDefault,
                          );
                          
                          addressProvider.addAddress(newAddress);
                        }
                        
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Update Address' : 'Save Address',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Helper to build address label selection buttons
  Widget _buildLabelOption(
    String label, 
    bool isSelected, 
    Color primaryColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryColor,
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Get current location and convert to address
  Future<void> _getCurrentLocationAddress(BuildContext context) async {
    final addressProvider = Provider.of<AddressProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;
        
    setState(() {
      _isLoadingCurrentLocation = true;
    });
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location services are disabled. Please enable them in settings.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingCurrentLocation = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission permanently denied. Please enable it in app settings.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'SETTINGS',
              textColor: Colors.white,
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
        return;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Create a more detailed address with null checks
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
        
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressComponents.add(place.administrativeArea!);
        }
        
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressComponents.add(place.postalCode!);
        }
        
        String currentAddress = addressComponents.join(', ');
        
        // Add the new address
        final newAddress = Address(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullAddress: currentAddress,
          label: 'Home',
          latitude: position.latitude,
          longitude: position.longitude,
          isDefault: addressProvider.addresses.isEmpty, // Make default if it's the first address
        );
        
        await addressProvider.addAddress(newAddress);
        
        // Call the callback with the new address
        widget.onAddressSelect(newAddress);
        
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address added successfully'),
            backgroundColor: primaryColor,
          ),
        );
      } else {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine address from your location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingCurrentLocation = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
