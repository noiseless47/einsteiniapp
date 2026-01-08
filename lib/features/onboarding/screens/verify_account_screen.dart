import 'package:flutter/material.dart';
import 'package:einsteiniapp/core/services/api_service.dart';
import 'package:einsteiniapp/core/utils/toast_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:einsteiniapp/core/routes/app_router.dart' as router;
import 'package:flutter_animate/flutter_animate.dart';

class VerifyAccountScreen extends StatefulWidget {
  final String email;
  
  const VerifyAccountScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim();
      ToastUtils.showInfoToast('Verifying your account...');
      
      final result = await _apiService.verifyAccount(
        email: widget.email,
        token: code,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Check if verification was successful
        if (result['success'] == true) {
          final message = result['message'] ?? 'Account verified successfully';
          ToastUtils.showSuccessToast(message);
          // Navigate to subscription screen since account is now verified
          // Use go instead of pushNamed to replace the current navigation stack
          context.go('/subscription');
        } else {
          final errorMessage = result['message'] ?? 'Verification failed';
          ToastUtils.showErrorToast(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastUtils.showErrorToast('Error: $e');
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      ToastUtils.showInfoToast('Resending verification code...');
      
      final result = await _apiService.resendVerification(widget.email);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (result['success']) {
          ToastUtils.showSuccessToast(result['message']);
        } else {
          ToastUtils.showErrorToast(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastUtils.showErrorToast('Error: $e');
      }
    }
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Verification code is required';
    }
    if (value.length < 6) {
      return 'Please enter the 6-digit code';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Account'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/einsteini_black.png'
                    : 'assets/images/einsteini_white.png',
                  height: 60,
                  width: 60,
                  fit: BoxFit.contain,
                ).animate().fadeIn(duration: 600.ms),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Verify Your Email',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Enter the 6-digit code we sent to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                
                const SizedBox(height: 32),
                
                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Code field
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Verification Code',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          counterText: '',
                        ),
                        validator: _validateCode,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verifyAccount(),
                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                      
                      const SizedBox(height: 24),
                      
                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyAccount,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Verify Account'),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                      
                      const SizedBox(height: 16),
                      
                      // Resend code
                      TextButton(
                        onPressed: _isLoading ? null : _resendCode,
                        child: const Text('Resend Code'),
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                      
                      const SizedBox(height: 16),
                      
                      // Back to login
                      TextButton(
                        onPressed: () => context.go(router.AppRoutes.auth),
                        child: const Text('Back to Login'),
                      ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 