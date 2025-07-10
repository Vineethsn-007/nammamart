import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signup() async {
    if (_isLoading) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Add haptic feedback
      HapticFeedback.mediumImpact();

      try {
        final userCredential = await _authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (userCredential.user != null) {
          await userCredential.user!.updateDisplayName(
            _nameController.text.trim(),
          );

          // After successful signup, navigate to home screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
                  return const HomeScreen();
                },
                transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                  const Offset begin = Offset(1.0, 0.0);
                  const Offset end = Offset.zero;
                  const Curve curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'User registration failed. Please try again.';
            _isLoading = false;
          });
          HapticFeedback.heavyImpact();
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            switch (e.code) {
              case 'email-already-in-use':
                _errorMessage =
                    'This email is already registered. Please use a different email or try logging in.';
                break;
              case 'weak-password':
                _errorMessage =
                    'The password is too weak. Please use a stronger password.';
                break;
              case 'invalid-email':
                _errorMessage = 'The email address is not valid.';
                break;
              default:
                _errorMessage =
                    e.message ??
                    'An error occurred during signup. Please try again.';
            }
          });
          HapticFeedback.heavyImpact();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'An unexpected error occurred: ${e.toString()}';
            _isLoading = false;
          });
          HapticFeedback.heavyImpact();
        }
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
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
          _errorMessage = 'Google sign-up was cancelled or failed.';
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error signing up with Google: ${e.toString()}';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? helperText,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.isDarkMode 
        ? themeProvider.darkPrimaryColor 
        : themeProvider.lightPrimaryColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade300 
                    : Colors.grey.shade800,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: themeProvider.isDarkMode 
                      ? Colors.red.shade800 
                      : Colors.red.shade300
                ),
              ),
              filled: true,
              fillColor: themeProvider.isDarkMode 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade50,
              hintStyle: TextStyle(
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade500 
                    : Colors.grey.shade500
              ),
            ),
            validator: validator,
            style: TextStyle(
              fontSize: 15,
              color: themeProvider.isDarkMode 
                  ? Colors.white 
                  : Colors.black87
            ),
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                helperText,
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required Color textColor,
    IconData? icon,
    bool isOutlined = false,
  }) {
    Provider.of<ThemeProvider>(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          foregroundColor: textColor,
          elevation: isOutlined ? 0 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isOutlined 
                ? BorderSide(color: color, width: 1.5) 
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 12),
            ],
            _isLoading && text == 'Create Account'
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
        ),
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
        : Colors.white;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'NammaStore',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.discount, size: 70, color: primaryColor),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign up to enjoy exclusive deals on groceries',
                            style: TextStyle(
                              fontSize: 16,
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey.shade400 
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'John Doe',
                            icon: Icons.person_outline,
                            validator: Validators.validateName,
                          ),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'hello@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                          ),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            validator: Validators.validatePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
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
                            helperText: 'Min. 8 characters with uppercase, number & symbol',
                          ),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirmPassword,
                            validator: _validateConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: themeProvider.isDarkMode 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_errorMessage.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
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
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _buildButton(
                            text: 'Create Account',
                            onPressed: _signup,
                            color: primaryColor,
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
                          _buildButton(
                            text: 'Continue with Google',
                            onPressed: _signUpWithGoogle,
                            color: themeProvider.isDarkMode 
                                ? Colors.grey.shade800 
                                : Colors.white,
                            textColor: themeProvider.isDarkMode 
                                ? Colors.grey.shade200 
                                : Colors.black87,
                            icon: Icons.g_mobiledata,
                            isOutlined: true,
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account?",
                                style: TextStyle(
                                  color: themeProvider.isDarkMode 
                                      ? Colors.grey.shade400 
                                      : Colors.grey.shade700,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 36),
                                ),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode 
                        ? Colors.grey.shade800 
                        : Colors.white,
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
                        'Creating account...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: themeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

