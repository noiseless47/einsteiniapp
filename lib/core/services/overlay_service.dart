import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'linkedin_service.dart';

/// Service to manage the floating overlay window
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.einsteini.ai/overlay');
  static final OverlayService _instance = OverlayService._internal();
  
  // Theme related properties
  ThemeMode? _currentThemeMode;
  bool _manuallySetTheme = false;

  // Stream controllers for overlay events
  final StreamController<bool> _overlayExpandedController = StreamController<bool>.broadcast();
  final StreamController<bool> _overlayCollapsedController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _linkedInContentDetectedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _generatedContentController = StreamController<String>.broadcast();

  final LinkedInService _linkedInService = LinkedInService();

  /// Singleton instance
  factory OverlayService() {
    return _instance;
  }

  OverlayService._internal() {
    // Setup method call handler
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Initialize theme
    _initTheme();
  }
  
  /// Initialize theme based on preferences and system settings
  Future<void> _initTheme() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? themeModeString = prefs.getString('theme_mode');
      
      // Parse theme mode from preferences
      if (themeModeString != null) {
        if (themeModeString == 'dark') {
          _currentThemeMode = ThemeMode.dark;
          _manuallySetTheme = true;
        } else if (themeModeString == 'light') {
          _currentThemeMode = ThemeMode.light;
          _manuallySetTheme = true;
        } else {
          _currentThemeMode = ThemeMode.system;
        }
      } else {
        _currentThemeMode = ThemeMode.system;
      }
      
      debugPrint('OverlayService: Theme initialized to $_currentThemeMode');
    } catch (e) {
      debugPrint('OverlayService: Error initializing theme: $e');
      _currentThemeMode = ThemeMode.system;
    }
  }

  // Function to get the current theme brightness
  bool _isDarkTheme(BuildContext? context) {
    if (_manuallySetTheme && _currentThemeMode != null) {
      if (_currentThemeMode == ThemeMode.dark) return true;
      if (_currentThemeMode == ThemeMode.light) return false;
    }
    
    // If using system theme or context is provided, check platform/context brightness
    final brightness = context != null 
        ? MediaQuery.of(context).platformBrightness 
        : WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  /// Stream to listen for overlay expanded events
  Stream<bool> get onOverlayExpanded => _overlayExpandedController.stream;

  /// Stream to listen for overlay collapsed events
  Stream<bool> get onOverlayCollapsed => _overlayCollapsedController.stream;
  
  /// Stream to listen for detected LinkedIn content
  Stream<Map<String, dynamic>> get onLinkedInContentDetected => _linkedInContentDetectedController.stream;
  
  /// Stream to listen for generated content
  Stream<String> get onGeneratedContent => _generatedContentController.stream;

  /// Handle method calls from the native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onOverlayExpanded':
        _overlayExpandedController.add(true);
        break;
      case 'onOverlayCollapsed':
        _overlayCollapsedController.add(true);
        break;
      case 'onLinkedInContentDetected':
        final Map<String, dynamic> content = Map<String, dynamic>.from(call.arguments);
        _linkedInContentDetectedController.add(content);
        break;
      case 'onGeneratedContentReady':
        final String generatedContent = call.arguments as String;
        _generatedContentController.add(generatedContent);
        break;
    }
    return null;
  }
  
  /// Generate LinkedIn comment based on detected content
  Future<String> generateLinkedInComment({
    required String postContent,
    required String author,
    required String commentType,
    String? imageUrl,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      final result = await _linkedInService.generateComment(
        postContent: postContent,
        author: author,
        commentType: commentType,
        imageUrl: imageUrl,
      );
      
      // Send the generated comment to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'comment',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to generate comment: $e');
      return 'Error generating comment';
    }
  }
  
  /// Generate a personalized comment with specific tone and details
  Future<String> generatePersonalizedComment({
    required String postContent,
    required String author,
    required String tone,
    required String toneDetails,
    String? imageUrl,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      final result = await _linkedInService.generatePersonalizedComment(
        postContent: postContent,
        author: author,
        tone: tone,
        toneDetails: toneDetails,
        imageUrl: imageUrl,
      );
      
      // Send the generated comment to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'personalized_comment',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to generate personalized comment: $e');
      return 'Error generating personalized comment';
    }
  }
  
  /// Generate a LinkedIn post
  Future<String> generateLinkedInPost({
    required String prompt,
    String? framework,
    String? tone,
    String? toneDetails,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      final result = await _linkedInService.generatePost(
        prompt: prompt,
        framework: framework,
        tone: tone,
        toneDetails: toneDetails,
      );
      
      // Send the generated post to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'post',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to generate post: $e');
      return 'Error generating post';
    }
  }
  
  /// Generate or modify a LinkedIn About section
  Future<String> generateLinkedInAbout({
    required String currentAbout,
    required String buttonType,
    String? company,
    String? experience,
    String? toneDetails,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      final result = await _linkedInService.generateAboutSection(
        currentAbout: currentAbout,
        buttonType: buttonType,
        company: company,
        experience: experience,
        toneDetails: toneDetails,
      );
      
      // Send the generated about section to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'about',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to generate about section: $e');
      return 'Error generating About section';
    }
  }
  
  /// Generate connection note
  Future<String> generateConnectionNote({
    required String profileName,
    required String about,
    String? mutual,
    String? buttonType,
    String? tone,
    String? toneDetails,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      final result = await _linkedInService.generateConnectionNote(
        profileName: profileName,
        about: about,
        mutual: mutual,
        buttonType: buttonType,
        tone: tone,
        toneDetails: toneDetails,
      );
      
      // Send the generated note to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'connection_note',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to generate connection note: $e');
      return 'Error generating connection note';
    }
  }
  
  /// Translate content
  Future<String> translateContent({
    required String content,
    required String language,
    String? author,
  }) async {
    if (!Platform.isAndroid) {
      return 'Feature only available on Android';
    }
    
    try {
      // First check if the language is Default/unselected
      if (language.toLowerCase() == 'default' || language.isEmpty) {
        const errorMsg = 'Please select a language for translation';
        debugPrint(errorMsg);
        return errorMsg;
      }
      
      final result = await _linkedInService.translateContent(
        content: content,
        targetLanguage: language,
        author: author,
        formatForDisplay: true,
      );
      
      debugPrint('Translation result: ${result['translation']}');
      
      // Check if there was an error in translation
      if (result.containsKey('error')) {
        final errorMsg = result['error'] ?? 'Unknown translation error';
        debugPrint('Translation error: $errorMsg');
        final translatedContent = 'Error: Failed to translate - $errorMsg';
        
        // Still show the error in the overlay
        await _channel.invokeMethod('showGeneratedContent', {
          'content': translatedContent,
          'type': 'translation',
        });
        
        return translatedContent;
      }
      
      final translatedContent = result['formattedTranslation'] ?? result['translation'] ?? 'Translation error';
      
      // Send the translation to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': translatedContent,
        'type': 'translation',
      });
      
      return translatedContent;
    } catch (e) {
      final errorMsg = 'Failed to translate content: $e';
      debugPrint(errorMsg);
      
      // Show error in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': 'Error: $errorMsg',
        'type': 'translation',
      });
      
      return 'Error translating content: $e';
    }
  }
  
  /// Correct grammar
  Future<String> correctGrammar(String text) async {
    if (!Platform.isAndroid) {
      return text;
    }
    
    try {
      final result = await _linkedInService.correctGrammar(text);
      
      // Send the corrected text to be displayed in the overlay
      await _channel.invokeMethod('showGeneratedContent', {
        'content': result,
        'type': 'grammar_correction',
      });
      
      return result;
    } catch (e) {
      debugPrint('Failed to correct grammar: $e');
      return text;
    }
  }
  
  /// Save LinkedIn profile
  Future<bool> saveProfile({
    required String name,
    required String title,
    required String about,
    required String url,
    String? mutual,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      return await _linkedInService.saveProfile(
        name: name,
        title: title,
        about: about,
        url: url,
        mutual: mutual,
      );
    } catch (e) {
      debugPrint('Failed to save profile: $e');
      return false;
    }
  }

  /// Start the overlay service
  ///
  /// Returns true if the service was started successfully
  Future<bool> startOverlayService({bool? isDarkMode}) async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final bool result = await _channel.invokeMethod('startOverlayService', {
        'isDarkMode': isDarkMode ?? _isDarkTheme(null),
      });
      return result;
    } catch (e) {
      debugPrint('Failed to start overlay service: $e');
      return false;
    }
  }
  
  /// Update the theme of the overlay
  Future<bool> updateOverlayTheme(bool isDarkTheme) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      debugPrint('OverlayService: Updating overlay theme to isDarkMode: $isDarkTheme');
      return await _channel.invokeMethod('updateOverlayTheme', {
        'isDarkMode': isDarkTheme
      }) ?? false;
    } on PlatformException catch (e) {
      debugPrint('OverlayService: Failed to update overlay theme: ${e.message}');
      return false;
    }
  }

  /// Set app theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _currentThemeMode = mode;
    _manuallySetTheme = true;
    
    // Save theme mode to preferences
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String themeModeString;
      switch (mode) {
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        default:
          themeModeString = 'system';
          _manuallySetTheme = false;
      }
      
      await prefs.setString('theme_mode', themeModeString);
      
      // Update overlay if it's running
      final isDarkTheme = mode == ThemeMode.dark || 
                         (mode == ThemeMode.system && 
                          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
      
      await updateOverlayTheme(isDarkTheme);
      debugPrint('OverlayService: Theme mode set to $mode, isDarkTheme: $isDarkTheme');
    } catch (e) {
      debugPrint('OverlayService: Failed to save theme mode: $e');
    }
  }

  /// Stop the overlay service
  ///
  /// Returns true if the service was stopped successfully
  Future<bool> stopOverlayService() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      return await _channel.invokeMethod('stopOverlayService') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to stop overlay service: ${e.message}');
      return false;
    }
  }

  /// Check if the overlay service is running
  ///
  /// Returns true if the service is running
  Future<bool> isOverlayServiceRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      return await _channel.invokeMethod('isOverlayServiceRunning') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check if overlay service is running: ${e.message}');
      return false;
    }
  }

  /// Resize the expanded overlay view
  ///
  /// [width] and [height] must be greater than 0
  /// Returns true if the resize was successful
  Future<bool> resizeExpandedView(int width, int height) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      return await _channel.invokeMethod('resizeExpandedView', {
        'width': width,
        'height': height,
      }) ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to resize expanded view: ${e.message}');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _overlayExpandedController.close();
    _overlayCollapsedController.close();
    _linkedInContentDetectedController.close();
    _generatedContentController.close();
  }
  
  /// Send custom action to overlay
  Future<bool> sendActionToOverlay(String action, [Map<String, dynamic>? data]) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final Map<String, dynamic> args = {
        'action': action,
      };
      
      if (data != null) {
        args['data'] = data;
      }
      
      return await _channel.invokeMethod('sendAction', args) ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to send action to overlay: ${e.message}');
      return false;
    }
  }

  /// Process a social media URL (LinkedIn, X/Twitter) in the overlay
  Future<bool> processSocialUrl(String url) async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      // First make sure the overlay service is running
      final bool isRunning = await isOverlayServiceRunning();
      if (!isRunning) {
        final bool started = await startOverlayService();
        if (!started) {
          debugPrint('Failed to start overlay service');
          return false;
        }
      }
      
      // Send the URL to the overlay service
      final bool result = await _channel.invokeMethod('processSocialUrl', {
        'url': url,
      });
      return result;
    } catch (e) {
      debugPrint('Failed to process social URL: $e');
      return false;
    }
  }
  
  /// @deprecated Use [processSocialUrl] instead.
  @Deprecated('Use processSocialUrl instead')
  Future<bool> processLinkedInUrl(String url) => processSocialUrl(url);
  
  /// Translate content in the overlay
  Future<bool> translateContentInOverlay({
    required String content,
    required String targetLanguage,
    String? author,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final result = await _linkedInService.translateContent(
        content: content,
        targetLanguage: targetLanguage,
        author: author,
        formatForDisplay: true,
      );
      
      // Send the translated content to be displayed in the overlay
      await _channel.invokeMethod('showTranslatedContent', {
        'original': content,
        'translation': result['translation'] ?? 'Translation error',
        'language': targetLanguage,
      });
      
      return true;
    } catch (e) {
      debugPrint('Failed to translate content: $e');
      return false;
    }
  }
  
  /// Generate comment options for the overlay
  Future<bool> generateCommentOptions({
    required String content,
    required String author,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      // Generate three different comment options with different tones
      final professionalComment = await _linkedInService.generateComment(
        postContent: content,
        author: author,
        commentType: 'Professional',
      );
      
      final questionComment = await _linkedInService.generateComment(
        postContent: content,
        author: author,
        commentType: 'Question',
      );
      
      final thoughtfulComment = await _linkedInService.generateComment(
        postContent: content,
        author: author,
        commentType: 'Thoughtful',
      );
      
      // Send the comment options to be displayed in the overlay
      await _channel.invokeMethod('showCommentOptions', {
        'professional': professionalComment,
        'question': questionComment,
        'thoughtful': thoughtfulComment,
      });
      
      return true;
    } catch (e) {
      debugPrint('Failed to generate comment options: $e');
      return false;
    }
  }
} 