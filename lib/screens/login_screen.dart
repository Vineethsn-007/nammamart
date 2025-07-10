import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../providers/theme_provider.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _obscurePassword = true;
  
  int _activeDotIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
    
    // Auto-advance pages
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _startAutoScroll();
      }
    });
  }
  
  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _pageController.hasClients) {
        final nextPage = (_activeDotIndex + 1) % 3;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
      try {
        await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          switch (e.code) {
            case 'user-not-found':
              _errorMessage = 'No user found with this email.';
              break;
            case 'wrong-password':
              _errorMessage = 'Incorrect password. Please try again.';
              break;
            case 'invalid-email':
              _errorMessage = 'Invalid email address format.';
              break;
            case 'user-disabled':
              _errorMessage = 'This user account has been disabled.';
              break;
            default:
              _errorMessage = e.message ?? 'An error occurred during login. Please try again.';
          }
        });
        // Error haptic feedback
        HapticFeedback.heavyImpact();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
        });
        // Error haptic feedback
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in was cancelled or failed.';
        });
        // Error haptic feedback
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error signing in with Google: ${e.toString()}';
      });
      // Error haptic feedback
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address first';
      });
      // Error haptic feedback
      HapticFeedback.heavyImpact();
      return;
    }

    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    try {
      await _authService.resetPassword(email);
      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final primaryColor = themeProvider.isDarkMode 
            ? themeProvider.darkPrimaryColor 
            : themeProvider.lightPrimaryColor;
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset email sent. Please check your inbox.'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'user-not-found') {
            _errorMessage = 'There is no user record corresponding to this email. Please check the email address.';
          } else {
            _errorMessage = 'Failed to send password reset email. Please try again.';
          }
        });
      }
      // Error haptic feedback
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred while sending password reset email: ${e.toString()}';
        });
      }
      // Error haptic feedback
      HapticFeedback.heavyImpact();
    }
  }

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return ElevatedButton.icon(
      icon: Icon(icon, color: color, size: 20),
      label: Text(
        text, 
        style: TextStyle(
          fontSize: 15, 
          fontWeight: FontWeight.w500, 
          color: themeProvider.isDarkMode ? Colors.grey.shade200 : Colors.grey.shade800
        )
      ),
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
        elevation: 1,
        shadowColor: themeProvider.isDarkMode ? Colors.black26 : Colors.grey.shade200,
        side: BorderSide(
          color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200
        ),
      ),
    );
  }
  
  Widget _buildOnboardingItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 160,
          width: 160,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: themeProvider.isDarkMode 
                    ? Colors.black26 
                    : Colors.grey.shade200,
                offset: const Offset(0, 4),
                blurRadius: 15,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 80, color: primaryColor),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: themeProvider.isDarkMode ? Colors.grey.shade300 : Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
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
        : Colors.white;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Text(
                            'NammaStore',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _activeDotIndex = index;
                          });
                        },
                        children: [
                          _buildOnboardingItem(
                            title: 'Fast Delivery',
                            subtitle: 'Get fresh groceries delivered to your doorstep in minutes, not hours.',
                            icon: Icons.delivery_dining,
                          ),
                          _buildOnboardingItem(
                            title: 'Exclusive Deals',
                            subtitle: 'Members save up to 40% on everyday essentials and premium products.',
                            icon: Icons.discount,
                          ),
                          _buildOnboardingItem(
                            title: 'Local Favorites',
                            subtitle: 'Discover and support local businesses with our curated selection.',
                            icon: Icons.map,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _activeDotIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _activeDotIndex == index ? primaryColor : themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to login form
                              _showLoginSheet(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(tween);
                                    return SlideTransition(position: offsetAnimation, child: child);
                                  },
                                  transitionDuration: const Duration(milliseconds: 500),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: primaryColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600, 
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Full-screen loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Signing in...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLoginSheet(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    final backgroundColor = themeProvider.isDarkMode 
        ? themeProvider.darkCardColor 
        : Colors.white;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.isDarkMode 
                        ? Colors.black26 
                        : Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade700 
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue shopping',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: themeProvider.isDarkMode 
                              ? Colors.grey.shade400 
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 36),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'hello@example.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
                          floatingLabelStyle: TextStyle(color: primaryColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          filled: true,
                          fillColor: themeProvider.isDarkMode 
                              ? Colors.grey.shade800 
                              : Colors.grey.shade50,
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade300 
                                : null
                          ),
                          hintStyle: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade500 
                                : Colors.grey.shade500
                          ),
                        ),
                        validator: Validators.validateEmail,
                        style: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black87
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: '••••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade400 
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          floatingLabelStyle: TextStyle(color: primaryColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          filled: true,
                          fillColor: themeProvider.isDarkMode 
                              ? Colors.grey.shade800 
                              : Colors.grey.shade50,
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade300 
                                : null
                          ),
                          hintStyle: TextStyle(
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade500 
                                : Colors.grey.shade500
                          ),
                        ),
                        validator: Validators.validatePassword,
                        style: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black87
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            textStyle: const TextStyle(fontWeight: FontWeight.w500),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode 
                                  ? Colors.red.shade900.withOpacity(0.3) 
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: themeProvider.isDarkMode 
                                    ? Colors.red.shade800 
                                    : Colors.red.shade200
                              ),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: themeProvider.isDarkMode 
                                    ? Colors.red.shade300 
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          _login();
                          Navigator.pop(context); // Close the bottom sheet
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'SIGN IN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300, 
                              thickness: 1.5
                            )
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: themeProvider.isDarkMode 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade700 
                                  : Colors.grey.shade300, 
                              thickness: 1.5
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildSocialButton(
                        text: 'Continue with Google',
                        icon: Icons.g_mobiledata,
                        color: Colors.red,
                        onPressed: () {
                          _signInWithGoogle();
                          Navigator.pop(context); // Close the bottom sheet
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade400 
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(tween);
                                    return SlideTransition(position: offsetAnimation, child: child);
                                  },
                                  transitionDuration: const Duration(milliseconds: 500),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

