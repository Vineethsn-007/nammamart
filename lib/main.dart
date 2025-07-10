import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/address_provider.dart'; // Add this import
import 'widgets/network_aware_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()), // Add the AddressProvider
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'NammaStore',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getTheme(),
            home: StreamBuilder<User?>(
              stream: _authService.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  final User? user = snapshot.data;
                  
                  // Wrap the main app with NetworkAwareWidget
                  return NetworkAwareWidget(
                    onlineChild: user == null ? const LoginScreen() : const HomeScreen(),
                  );
                }
                
                // Loading state
                return Scaffold(
                  key: const Key('loading_scaffold'),
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(themeProvider.lightPrimaryColor),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
