import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:einsteiniapp/core/constants/app_constants.dart';
import 'package:einsteiniapp/core/routes/app_router.dart' as router;
import 'package:einsteiniapp/core/theme/theme_provider.dart';
import 'package:einsteiniapp/core/widgets/app_logo.dart';
import 'package:einsteiniapp/core/utils/toast_utils.dart';

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  ThemeMode _selectedTheme = ThemeMode.system;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  void _loadCurrentTheme() {
    final currentTheme = ref.read(themeProvider);
    setState(() {
      _selectedTheme = currentTheme;
    });
  }

  Future<void> _saveThemeAndContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save theme preference to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', _selectedTheme.name);
      
      // Update the theme using the provider
      ref.read(themeProvider.notifier).setTheme(_selectedTheme);
      
      // Mark onboarding as completed
      await prefs.setBool(AppConstants.hasCompletedOnboardingKey, true);
      
      // Navigate to the auth screen instead of home
      if (mounted) {
        context.go(router.AppRoutes.auth);
      }
    } catch (e) {
      // Show error toast instead of snackbar
      ToastUtils.showErrorToast('Error saving theme: $e');
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoImage = isDarkMode ? 'assets/images/einsteini_black.png' : 'assets/images/einsteini_white.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Theme'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: const AppLogo(
                          size: 70,
                          padding: 10,
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                      
                      const SizedBox(height: 40),
                      
                      Text(
                        'Choose Your Theme',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Select a theme that matches your style for the best LinkedIn engagement experience.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                      
                      const SizedBox(height: 40),
                      
                      _buildThemeOption(
                        context,
                        title: 'Light Theme',
                        description: 'Clean, bright interface',
                        icon: Icons.light_mode,
                        isSelected: _selectedTheme == ThemeMode.light,
                        onTap: () {
                          setState(() {
                            _selectedTheme = ThemeMode.light;
                          });
                        },
                      ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                      
                      const SizedBox(height: 16),
                      
                      _buildThemeOption(
                        context,
                        title: 'Dark Theme',
                        description: 'Easy on the eyes, perfect for night',
                        icon: Icons.dark_mode,
                        isSelected: _selectedTheme == ThemeMode.dark,
                        onTap: () {
                          setState(() {
                            _selectedTheme = ThemeMode.dark;
                          });
                        },
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                      
                      const SizedBox(height: 16),
                      
                      _buildThemeOption(
                        context,
                        title: 'System Default',
                        description: 'Follows your device settings',
                        icon: Icons.settings_suggest,
                        isSelected: _selectedTheme == ThemeMode.system,
                        onTap: () {
                          setState(() {
                            _selectedTheme = ThemeMode.system;
                          });
                        },
                      ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
                      
                      const SizedBox(height: 40),
                      
                      // Theme preview
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Preview',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: _buildThemePreview(context, _selectedTheme),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                    ],
                  ),
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveThemeAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text('Continue'),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent, // Changed from Theme.of(context).dividerColor to transparent
            width: isSelected ? 2 : 0, // Changed from 1 to 0 for non-selected
          ),
          borderRadius: BorderRadius.circular(12),
          // Add a subtle background color for better distinction without borders
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
              : Theme.of(context).colorScheme.surface.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemePreview(BuildContext context, ThemeMode currentTheme) {
    // Simple preview of how the UI will look in the selected theme
    final isDarkMode = currentTheme == ThemeMode.dark || 
        (currentTheme == ThemeMode.system && 
        MediaQuery.of(context).platformBrightness == Brightness.dark);
    
    final previewColor = isDarkMode 
        ? const Color(0xFF121827)  // Dark theme surface color
        : Colors.white;            // Light theme surface color
    
    final textColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1A1D24);
        
    final primaryColor = isDarkMode
        ? const Color(0xFF4B9CFF)  // Dark theme primary color
        : const Color(0xFF007AFF); // Light theme primary color
    
    return Container(
      width: 200,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'einsteini.ai',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 