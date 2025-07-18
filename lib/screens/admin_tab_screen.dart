import 'package:flutter/material.dart';
import 'package:namma_mart/screens/admin_orders_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'admin_product_screen.dart';
import 'admin_settings_screen.dart';

class AdminTabScreen extends StatefulWidget {
  const AdminTabScreen({Key? key}) : super(key: key);

  @override
  _AdminTabScreenState createState() => _AdminTabScreenState();
}

class _AdminTabScreenState extends State<AdminTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper to allow children to switch tabs
  void _goToTab(int index) {
    _tabController.animateTo(index);
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
          'Admin Dashboard',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: themeProvider.isDarkMode
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          tabs: const [
            Tab(
              icon: Icon(Icons.inventory),
              text: 'Products',
            ),
            Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Orders',
            ),
            Tab(
              icon: Icon(Icons.settings),
              text: 'Settings',
            ),
            Tab(
              icon: Icon(Icons.admin_panel_settings),
              text: 'Admin Tools',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Products Tab with navigation example
          Column(
            children: [
              Expanded(child: AdminProductScreen()),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _goToTab(1),
                      child: const Text('Go to Orders'),
                    ),
                    ElevatedButton(
                      onPressed: () => _goToTab(2),
                      child: const Text('Go to Settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Orders Tab with navigation example
          Column(
            children: [
              Expanded(child: AdminOrdersScreen()),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _goToTab(0),
                      child: const Text('Go to Products'),
                    ),
                    ElevatedButton(
                      onPressed: () => _goToTab(2),
                      child: const Text('Go to Settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Settings Tab with navigation example
          Column(
            children: [
              Expanded(child: AdminSettingsScreen()),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _goToTab(0),
                      child: const Text('Go to Products'),
                    ),
                    ElevatedButton(
                      onPressed: () => _goToTab(1),
                      child: const Text('Go to Orders'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Admin Tools Tab (placeholder for future features)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Admin Tools (Coming Soon)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _goToTab(0),
                  child: const Text('Go to Products'),
                ),
                ElevatedButton(
                  onPressed: () => _goToTab(2),
                  child: const Text('Go to Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
