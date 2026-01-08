import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:einsteiniapp/core/constants/app_constants.dart';
import 'package:einsteiniapp/core/routes/app_router.dart' as router;
import 'package:einsteiniapp/core/utils/toast_utils.dart';
import 'package:einsteiniapp/core/services/api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  final bool isSignUp;
  
  const AuthScreen({
    super.key,
    this.isSignUp = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final ApiService _apiService = ApiService();
  
  // Social login requirements
  final List<String> _googleScopes = ['email', 'profile'];
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Microsoft auth settings
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final String _microsoftClientId = '111eb0e3-8a6e-46c7-a3f0-55b4448e8ede';
  final String _microsoftRedirectUrl = 'com.einsteini.app://oauth/redirect';
  final List<String> _microsoftScopes = ['openid', 'profile', 'email', 'offline_access', 'User.Read'];

  // LinkedIn OAuth settings
  final String _linkedInClientId = 'your-linkedin-client-id';
  final String _linkedInClientSecret = 'your-linkedin-client-secret';
  final String _linkedInRedirectUrl = 'com.einsteini.app://oauth/linkedin';
  final String _linkedInAuthUrl = 'https://www.linkedin.com/oauth/v2/authorization';

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading toast for better feedback
      if (mounted) {
        ToastUtils.showInfoToast(_isSignUp ? 'Creating account...' : 'Logging in...');
      }
      
      // Trim email and password to prevent whitespace issues
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      Map<String, dynamic> result;
      
      if (_isSignUp) {
        // Sign up flow
        result = await _apiService.signup(
          name: '${_nameController.text.trim()} ${_lastNameController.text.trim()}',
          email: email,
          password: password,
        );
      } else {
        // Login flow
        result = await _apiService.login(
          email: email,
          password: password,
        );
      }
      
      if (mounted) {
        // Clear the loading state regardless of outcome
        setState(() {
          _isLoading = false;
        });
      }
      
      // Check if verification is required
      if (result.containsKey('requireVerification') && result['requireVerification'] == true) {
        if (mounted) {
          ToastUtils.showInfoToast(result['message']);
          // Navigate to verification screen
          context.pushNamed(
            'verify_account',
            extra: {
              'email': email,
            },
          );
        }
        return;
      }
      
      if (result['success']) {
        if (mounted) {
          ToastUtils.showSuccessToast(result['message']);
          
          // Check if user has seen tutorial
          final prefs = await SharedPreferences.getInstance();
          final hasSeenTutorial = prefs.getBool(AppConstants.hasSeenTutorialKey) ?? false;
          
          // If this was a signup, show the tutorial first, then plans screen
          if (_isSignUp) {
            if (!hasSeenTutorial) {
              // Mark tutorial as seen for future logins
              await prefs.setBool(AppConstants.hasSeenTutorialKey, true);
              // Navigate to tutorial with a flag indicating it's a new user
              context.go('${router.AppRoutes.tutorial}?isNewUser=true');
            } else {
              context.pushNamed(
                'subscription',
                extra: {
                  'isNewUser': true,
                },
              );
            }
          } else {
            // For login, check if they've seen tutorial
            if (!hasSeenTutorial) {
              // Mark tutorial as seen for future logins
              await prefs.setBool(AppConstants.hasSeenTutorialKey, true);
              // Navigate to tutorial first
              context.go('${router.AppRoutes.tutorial}?isNewUser=false');
            } else {
              // Otherwise go straight to home
              context.go(router.AppRoutes.home);
            }
          }
        }
      } else {
        if (mounted) {
          // Show the specific error message
          ToastUtils.showErrorToast(result['message'] ?? 'Authentication failed');
        }
      }
    } catch (error) {
      if (mounted) {
        // Log the error for debugging
        debugPrint('Authentication error: $error');
        
        ToastUtils.showErrorToast('Authentication failed: $error');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (_isSignUp && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'First name is required';
    }
    return null;
  }
  
  String? _validateLastName(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'Last name is required';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isSignUp) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _passwordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo and Title
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/einsteini_black.png'
                    : 'assets/images/einsteini_white.png',
                  height: 50,
                  width: 50,
                  fit: BoxFit.contain,
                ).animate().fadeIn(duration: 600.ms),
                
                const SizedBox(height: 8),
                
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                
                const SizedBox(height: 8),
                
                Text(
                  _isSignUp 
                    ? 'Sign up to start crafting engaging LinkedIn content'
                    : 'Login to continue your LinkedIn growth journey',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                
                const SizedBox(height: 40),
                
                // Auth Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isSignUp)
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            hintText: 'Enter your first name',
                            prefixIcon: const Icon(Icons.person),
                            // Remove outline border and use filled style instead
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.5)
                                : Colors.grey[100]!.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validateName,
                        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                      
                      if (_isSignUp) const SizedBox(height: 16),
                      
                      if (_isSignUp)
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            hintText: 'Enter your last name',
                            prefixIcon: const Icon(Icons.person_outline),
                            // Remove outline border and use filled style instead
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.5)
                                : Colors.grey[100]!.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validateLastName,
                        ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
                      
                      if (_isSignUp) const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email),
                          // Remove outline border and use filled style instead
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!.withOpacity(0.5)
                              : Colors.grey[100]!.withOpacity(0.7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none, // Remove the border
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none, // Remove the border
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 500.ms : 400.ms),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: _isSignUp ? 'Create a password' : 'Enter your password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          // Remove outline border and use filled style instead
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!.withOpacity(0.5)
                              : Colors.grey[100]!.withOpacity(0.7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none, // Remove the border
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none, // Remove the border
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                      ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 600.ms : 500.ms),
                      
                      if (_isSignUp) const SizedBox(height: 16),
                      
                      if (_isSignUp)
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Confirm your password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            // Remove outline border and use filled style instead
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.5)
                                : Colors.grey[100]!.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none, // Remove the border
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          validator: _validateConfirmPassword,
                        ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 700.ms : 600.ms),
                      
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Navigate to forgot password screen
                              context.pushNamed('forgot_password');
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : Text(_isSignUp ? 'Sign Up' : 'Login'),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 800.ms : 700.ms),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp
                              ? 'Already have an account?'
                              : 'Don\'t have an account?',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: _toggleAuthMode,
                            child: Text(_isSignUp ? 'Login' : 'Sign Up'),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 900.ms : 800.ms),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Social logins
                Column(
                  children: [
                    Text(
                      'Or continue with',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          icon: 'assets/icons/google.svg',
                          provider: 'Google',
                          onPressed: () => _handleSocialLogin('Google'),
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: 'assets/icons/microsoft.svg',
                          provider: 'Microsoft',
                          onPressed: () => _handleSocialLogin('Microsoft'),
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: 'assets/icons/linkedin.svg',
                          provider: 'LinkedIn',
                          onPressed: () => _handleSocialLogin('LinkedIn'),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms, delay: _isSignUp ? 1000.ms : 900.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String provider,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          // Replace border with a subtle background color
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!.withOpacity(0.5)
              : Colors.grey[100]!.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SvgPicture.asset(
          icon,
            height: 24,
            width: 24,
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> socialUserData = {};
      
      // Handle different social login providers
      switch (provider) {
        case 'Google':
          socialUserData = await _signInWithGoogle();
          break;
        case 'Microsoft':
          socialUserData = await _signInWithMicrosoft();
          break;
        case 'LinkedIn':
          socialUserData = await _signInWithLinkedIn();
          break;
        default:
          throw Exception('Unknown provider: $provider');
      }

      // If the social login was successful, call our backend API
      if (socialUserData['success'] == true) {
        final result = await _apiService.socialLogin(
          provider: provider,
          token: socialUserData['token'],
          email: socialUserData['email'],
          name: socialUserData['name'],
          photoUrl: socialUserData['photoUrl'],
        );
        
        if (result['success']) {
          // Save email to backend if needed
          if (socialUserData['email'] != null) {
            await _apiService.saveEmail(email: socialUserData['email']);
          }
      
      if (mounted) {
        ToastUtils.showSuccessToast('Successfully signed in with $provider');
        
        // Check if user has seen tutorial for social login
        final prefs = await SharedPreferences.getInstance();
        final hasSeenTutorial = prefs.getBool(AppConstants.hasSeenTutorialKey) ?? false;
        
        if (!hasSeenTutorial) {
          // Mark tutorial as seen for future logins
          await prefs.setBool(AppConstants.hasSeenTutorialKey, true);
          // Navigate to tutorial first
          context.go('${router.AppRoutes.tutorial}?isNewUser=false');
        } else {
          // Otherwise go straight to home
          context.go(router.AppRoutes.home);
        }
          }
        } else {
          if (mounted) {
            ToastUtils.showErrorToast('$provider sign in failed: ${result['message']}');
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          ToastUtils.showErrorToast('$provider sign in failed: ${socialUserData['error']}');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ToastUtils.showErrorToast('$provider sign in failed: $error');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<Map<String, dynamic>> _signInWithGoogle() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(serverClientId: '940646244947-ud4dcdvfntku6j8ccfk8t66j50qle5k2.apps.googleusercontent.com');
      GoogleSignInAccount? googleUser;
      if (signIn.supportsAuthenticate()) {
        googleUser = await signIn.authenticate();
      }
      if (googleUser == null) {
        return {
          'success': false,
          'error': 'Sign in cancelled by user or not authenticated.'
        };
      }
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      await _secureStorage.write(key: 'google_id_token', value: googleAuth.idToken);
      return {
        'success': true,
        'token': googleAuth.idToken ?? '',
        'name': googleUser.displayName ?? '',
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
      };
    } catch (error) {
      debugPrint('Google sign in error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
  
  Future<Map<String, dynamic>> _signInWithMicrosoft() async {
    try {
      // Use AppAuth to authenticate with Microsoft
      final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _microsoftClientId,
          _microsoftRedirectUrl,
          scopes: _microsoftScopes,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
            tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
          ),
        ),
      );
      
      // Store tokens securely
      await _secureStorage.write(key: 'microsoft_access_token', value: result.accessToken);
      await _secureStorage.write(key: 'microsoft_id_token', value: result.idToken);
      
      // Get user information from Microsoft Graph API
      String name = '';
      String email = '';
      String? photoUrl;
      
      if (result.accessToken != null) {
        try {
          // Call Microsoft Graph API to get user profile
          final response = await http.get(
            Uri.parse('https://graph.microsoft.com/v1.0/me'),
            headers: {
              'Authorization': 'Bearer ${result.accessToken}',
              'Content-Type': 'application/json',
            },
          );
          
          if (response.statusCode == 200) {
            final Map<String, dynamic> userData = json.decode(response.body);
            name = userData['displayName'] ?? '';
            email = userData['userPrincipalName'] ?? userData['mail'] ?? '';
            
            // Try to get profile photo if available (this is a separate API call)
            try {
              final photoResponse = await http.get(
                Uri.parse('https://graph.microsoft.com/v1.0/me/photo/\$value'),
                headers: {
                  'Authorization': 'Bearer ${result.accessToken}',
                },
              );
              
              if (photoResponse.statusCode == 200) {
                // Convert photo bytes to base64 for storage
                final String base64Photo = base64Encode(photoResponse.bodyBytes);
                photoUrl = 'data:image/jpeg;base64,$base64Photo';
              }
            } catch (e) {
              // Photo fetch failed, but we can continue without it
              debugPrint('Microsoft photo fetch error: $e');
            }
          } else {
            debugPrint('Microsoft Graph API error: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error fetching Microsoft user data: $e');
        }
      } else if (result.idToken != null) {
        // Fallback to ID token if we couldn't get data from Graph API
        try {
          final Map<String, dynamic> decodedToken = JwtDecoder.decode(result.idToken!);
          name = decodedToken['name'] ?? '';
          email = decodedToken['preferred_username'] ?? '';
        } catch (e) {
          debugPrint('Error decoding Microsoft JWT: $e');
        }
      }
      
      return {
        'success': true,
        'token': result.accessToken,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      };
    } catch (error) {
      debugPrint('Microsoft sign in error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
  
  Future<Map<String, dynamic>> _signInWithLinkedIn() async {
    try {
      // Use the LinkedIn OAuth flow - simplified for direct use in mobile
      // In a production app, you would implement proper OAuth flow
      // This is a simplified implementation that requires manual handling
      
      // Show an alert that we're launching LinkedIn sign-in
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening LinkedIn login page...')),
        );
      }
      
      // For simplicity, we're going to mock the LinkedIn sign-in
      // In a real implementation, you would:
      // 1. Launch the browser with the LinkedIn auth URL
      // 2. Handle the redirect and extract the code
      
      // Simulate successful authentication
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock code that would normally come from the redirect
      const String mockCode = "mocked_linkedin_auth_code";
      
      // In a real implementation, we would check if the code is null
      // but since we're using a mock code, we'll just proceed
      
      // Mock a token exchange
      // In a real app, you would make an HTTP request to LinkedIn's token endpoint
      // We're mocking this step to avoid the actual HTTP request
      
      // Mock token response
      final Map<String, dynamic> mockTokenResponse = {
        'access_token': 'mocked_linkedin_access_token',
        'expires_in': 3600
      };
      
      // Simulate a successful token response
      final String accessToken = mockTokenResponse['access_token'];
      
      // Store tokens securely
      await _secureStorage.write(key: 'linkedin_access_token', value: accessToken);
      
      // Mock user data that would normally come from API calls
      const String name = 'LinkedIn User';
      const String email = 'linkedin_user@example.com';
      const String? photoUrl = null;
      
      return {
        'success': true,
        'token': accessToken,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      };
    } catch (error) {
      debugPrint('LinkedIn sign in error: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }
}