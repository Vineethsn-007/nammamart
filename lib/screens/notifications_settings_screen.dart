// Create a new file: lib/screens/notifications_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsSettingsScreenState createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _orderUpdates = true;
  bool _promotions = true;
  bool _deliveryAlerts = true;
  bool _appUpdates = false;

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
          'Notification Settings',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationSwitch(
              title: 'Order Updates',
              subtitle: 'Get notified about your order status',
              value: _orderUpdates,
              onChanged: (value) {
                setState(() {
                  _orderUpdates = value;
                });
              },
            ),
            _buildNotificationSwitch(
              title: 'Promotions & Offers',
              subtitle: 'Receive notifications about deals and discounts',
              value: _promotions,
              onChanged: (value) {
                setState(() {
                  _promotions = value;
                });
              },
            ),
            _buildNotificationSwitch(
              title: 'Delivery Alerts',
              subtitle: 'Get notified when your order is out for delivery',
              value: _deliveryAlerts,
              onChanged: (value) {
                setState(() {
                  _deliveryAlerts = value;
                });
              },
            ),
            _buildNotificationSwitch(
              title: 'App Updates',
              subtitle: 'Be informed about new app features and updates',
              value: _appUpdates,
              onChanged: (value) {
                setState(() {
                  _appUpdates = value;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Save notification preferences
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification preferences saved'),
                      backgroundColor: primaryColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode 
                ? Colors.black26 
                : Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: themeProvider.isDarkMode 
                ? Colors.grey.shade400 
                : Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}