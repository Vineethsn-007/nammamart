import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  _AdminSettingsScreenState createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final _deliveryFeeController = TextEditingController();
  final _deliveryThresholdController = TextEditingController();
  final _taxRateController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _deliveryFeeController.dispose();
    _deliveryThresholdController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();
      
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null) {
          setState(() {
            _deliveryFeeController.text = 
                ((data['deliveryFeeBase'] as num?)?.toDouble() ?? 40.0).toString();
            _deliveryThresholdController.text = 
                ((data['deliveryFeeThreshold'] as num?)?.toDouble() ?? 500.0).toString();
            _taxRateController.text = 
                ((data['taxRate'] as num?)?.toDouble() ?? 5.0).toString();
          });
        }
      } else {
        // Set default values if no settings document exists
        setState(() {
          _deliveryFeeController.text = '40.0';
          _deliveryThresholdController.text = '500.0';
          _taxRateController.text = '5.0';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading settings: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      // Parse values from controllers
      final deliveryFee = double.parse(_deliveryFeeController.text);
      final deliveryThreshold = double.parse(_deliveryThresholdController.text);
      final taxRate = double.parse(_taxRateController.text);
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .set({
        'deliveryFeeBase': deliveryFee,
        'deliveryFeeThreshold': deliveryThreshold,
        'taxRate': taxRate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving settings: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
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
          'Store Settings',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Delivery Fee Settings Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_shipping, color: primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Delivery Fee Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Base Delivery Fee
                            TextFormField(
                              controller: _deliveryFeeController,
                              decoration: InputDecoration(
                                labelText: 'Base Delivery Fee (₹)',
                                hintText: 'Enter base delivery fee',
                                prefixIcon: Icon(Icons.money, color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a delivery fee';
                                }
                                try {
                                  final fee = double.parse(value);
                                  if (fee < 0) {
                                    return 'Delivery fee cannot be negative';
                                  }
                                } catch (e) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Free Delivery Threshold
                            TextFormField(
                              controller: _deliveryThresholdController,
                              decoration: InputDecoration(
                                labelText: 'Free Delivery Threshold (₹)',
                                hintText: 'Enter minimum order amount for free delivery',
                                prefixIcon: Icon(Icons.card_giftcard, color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a threshold amount';
                                }
                                try {
                                  final threshold = double.parse(value);
                                  if (threshold < 0) {
                                    return 'Threshold cannot be negative';
                                  }
                                } catch (e) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Orders above this amount will qualify for free delivery',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Tax Settings Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.receipt_long, color: primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Tax Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Tax Rate
                            TextFormField(
                              controller: _taxRateController,
                              decoration: InputDecoration(
                                labelText: 'Tax Rate (%)',
                                hintText: 'Enter tax rate percentage',
                                prefixIcon: Icon(Icons.percent, color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a tax rate';
                                }
                                try {
                                  final rate = double.parse(value);
                                  if (rate < 0) {
                                    return 'Tax rate cannot be negative';
                                  }
                                  if (rate > 100) {
                                    return 'Tax rate cannot exceed 100%';
                                  }
                                } catch (e) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This tax rate will be applied to all orders',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Saving...'),
                                ],
                              )
                            : const Text(
                                'Save Settings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _deliveryFeeController.text = '40.0';
                            _deliveryThresholdController.text = '500.0';
                            _taxRateController.text = '5.0';
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Reset to Default Values',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
