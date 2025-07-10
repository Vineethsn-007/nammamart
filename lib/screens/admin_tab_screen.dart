import 'package:flutter/material.dart';
import 'package:namma_store/screens/admin_orders_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'admin_product_screen.dart';
import 'admin_settings_screen.dart';

class AdminTabScreen extends StatefulWidget {
  const AdminTabScreen({Key? key}) : super(key: key);

  @override
  _AdminTabScreenState createState() => _AdminTabScreenState();
}

class _AdminTabScreenState extends State<AdminTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminProductScreen(),
          AdminOrdersScreen(),
          AdminSettingsScreen(),
        ],
      ),
    );
  }
}
