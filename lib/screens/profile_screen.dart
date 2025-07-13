import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'notifications_settings_screen.dart';
import 'order_history_screen.dart';
import 'help_support_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  String? _profileImageUrl;
  File? _imageFile;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!_isMounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';

        final userData =
            await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;

          if (!_isMounted) return;

          setState(() {
            _nameController.text = data['name'] ?? user.displayName ?? '';
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
            _profileImageUrl = data['profileImageUrl'] ?? user.photoURL;
          });
        } else {
          if (!_isMounted) return;

          setState(() {
            _nameController.text = user.displayName ?? '';
            _profileImageUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');

      if (!_isMounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile data: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (!_isMounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null && _isMounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = _storage.ref().child('profile_images/${user.uid}');
      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
      });

      await user.updatePhotoURL(downloadUrl);

      if (!_isMounted) return;

      setState(() {
        _profileImageUrl = downloadUrl;
        _imageFile = null;
      });
    } catch (e) {
      print('Error uploading image: $e');

      if (!_isMounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isMounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_imageFile != null) {
        await _uploadImage();
      }

      if (_nameController.text != user.displayName) {
        await user.updateDisplayName(_nameController.text);
      }

      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'profileImageUrl': _profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!_isMounted) return;

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving profile: $e');

      if (!_isMounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (!_isMounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');

      if (!_isMounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildProfileImage() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: _imageFile != null
                ? Image.file(
                    _imageFile!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? Image.network(
                        _profileImageUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 60,
                            color: primaryColor,
                          );
                        },
                      )
                    : Icon(Icons.person, size: 60, color: primaryColor),
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode
                ? Colors.black12
                : Colors.grey.shade100,
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly || !_isEditing,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
        style: TextStyle(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode
        ? themeProvider.darkPrimaryColor
        : themeProvider.lightPrimaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode
                ? Colors.black12
                : Colors.grey.shade100,
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  fontSize: 14,
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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

    return Container(
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Text(
                'My Profile',
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (!_isEditing)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  color: primaryColor,
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.red.shade600,
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _loadUserData();
                    });
                  },
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading profile...',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 24),
                    Text(
                      _nameController.text,
                      style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email,
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (_isEditing &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                          ),
                          if (!_isEditing &&
                              _phoneController.text.trim().isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Phone number not set',
                                      style: TextStyle(
                                          color: Colors.orange.shade700)),
                                ],
                              ),
                            ),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Address',
                            icon: Icons.location_on,
                            maxLines: 3,
                            validator: (value) {
                              if (_isEditing &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter your address';
                              }
                              return null;
                            },
                          ),
                          if (!_isEditing &&
                              _addressController.text.trim().isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Address not set',
                                      style: TextStyle(
                                          color: Colors.orange.shade700)),
                                ],
                              ),
                            ),
                          if (_isEditing)
                            Container(
                              width: double.infinity,
                              margin:
                                  const EdgeInsets.only(top: 16, bottom: 32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.save),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Save Profile',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.6)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Settings',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSettingItem(
                        title: 'Dark Mode',
                        icon: themeProvider.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        subtitle: themeProvider.isDarkMode
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeColor: primaryColor,
                        ),
                        onTap: () {
                          themeProvider.toggleTheme();
                        },
                      ),
                      _buildSettingItem(
                        title: 'Order History',
                        icon: Icons.history,
                        subtitle: 'View your past orders',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => OrderHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        title: 'Help & Support',
                        icon: Icons.help,
                        subtitle: 'Contact customer support',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => HelpSupportScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        title: 'About',
                        icon: Icons.info,
                        subtitle: 'App version 1.0.0',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'NammaMart',
                            applicationVersion: '1.0.0',
                            applicationIcon: Icon(
                              Icons.shopping_basket,
                              color: primaryColor,
                              size: 50,
                            ),
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'NammaMart is your one-stop solution for grocery shopping. We provide fresh products delivered right to your doorstep.',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade600,
                              Colors.red.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade300,
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
