import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget onlineChild;
  final Widget? offlineChild;

  const NetworkAwareWidget({
    Key? key,
    required this.onlineChild,
    this.offlineChild,
  }) : super(key: key);

  @override
  _NetworkAwareWidgetState createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatusList);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _isMounted = false;
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (!_isMounted) return;
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    } catch (e) {
      print('Error checking connectivity: $e');
      if (!_isMounted) return;
      setState(() {
        _isOnline = false;
      });
    }
  }

  void _updateConnectionStatusList(List<ConnectivityResult> results) {
    if (!_isMounted) return;
    setState(() {
      _isOnline = results.any((result) => result != ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) {
      return widget.onlineChild;
    } else {
      if (widget.offlineChild != null) {
        return widget.offlineChild!;
      }
      
      // Default offline view
      final themeProvider = Provider.of<ThemeProvider>(context);
      final primaryColor = themeProvider.isDarkMode 
          ? themeProvider.darkPrimaryColor 
          : themeProvider.lightPrimaryColor;
      
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 80,
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade600 
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode 
                      ? Colors.white 
                      : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Please check your internet connection and try again',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _checkConnectivity();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
