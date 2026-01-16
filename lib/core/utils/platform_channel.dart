import 'dart:io';
import 'package:flutter/services.dart';
import 'package:einsteiniapp/core/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: deprecated_member_use_from_same_package
import 'package:einsteiniapp/core/services/linkedin_service.dart';

/// Utility class to handle platform-specific operations
class PlatformChannel {
  /// Share content to a social platform using Android intent
  static Future<void> shareToSocialPlatform(String content, {String platform = 'linkedin'}) async {
    try {
      await _platformChannel.invokeMethod('shareToSocialPlatform', {
        'content': content,
        'platform': platform,
      });
    } on PlatformException catch (e) {
      print('Failed to share to social platform: ${e.message}');
      rethrow;
    }
  }

  /// @deprecated Use [shareToSocialPlatform] instead.
  /// Share content to LinkedIn using Android intent
  @Deprecated('Use shareToSocialPlatform instead')
  static Future<void> shareToLinkedIn(String content) async {
    try {
      await _platformChannel.invokeMethod('shareToLinkedIn', {'content': content});
    } on PlatformException catch (e) {
      print('Failed to share to LinkedIn: ${e.message}');
      rethrow;
    }
  }
  static const MethodChannel _channel = MethodChannel('com.einsteini.ai/settings');
  static const MethodChannel _overlayChannel = MethodChannel('com.einsteini.ai/overlay');
  static const MethodChannel _platformChannel = MethodChannel('einsteini/platform');
  static final ApiService _apiService = ApiService();
  // ignore: deprecated_member_use_from_same_package
  static final LinkedInService _linkedInService = LinkedInService();
  
  // Callback for when content is scraped from the overlay
  static Function(Map<String, dynamic>)? onContentScraped;
  
  // Initialize the platform channel
  static void init() {
    _overlayChannel.setMethodCallHandler(_handleMethodCall);
  }
  
  // Handle method calls from the platform
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onContentScraped':
        if (onContentScraped != null) {
          final Map<String, dynamic> content = Map<String, dynamic>.from(call.arguments);
          onContentScraped!(content);
        }
        return null;
      case 'generateSummary':
        final content = call.arguments['content'] as String? ?? '';
        final author = call.arguments['author'] as String? ?? 'Unknown author';
        final summaryType = call.arguments['summaryType'] as String? ?? 'concise';
        return await generateSummary(content, author, summaryType);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Opens specific system settings pages on Android
  static Future<void> openSystemSettings(String action) async {
    try {
      await _channel.invokeMethod('openSystemSettings', {'action': action});
    } on PlatformException catch (e) {
      print('Failed to open system settings: ${e.message}');
      rethrow;
    }
  }

  /// Opens specific settings pages using Android intent actions
  static Future<void> openOverlayPermissionSettings() async {
    if (Platform.isAndroid) {
      try {
        print('Opening overlay permission settings...');
        await openSystemSettings('android.settings.MANAGE_OVERLAY_PERMISSION');
        print('Overlay permission settings opened successfully');
      } on PlatformException catch (e) {
        print('Failed to open overlay permission settings: ${e.message}');
        print('Error details: ${e.details}');
        // Try one more approach via permission_handler package as fallback
        try {
          await openAppSettings();
          print('Opened app settings as fallback');
        } catch (e2) {
          print('All attempts to open settings failed: $e2');
        }
      } catch (e) {
        print('Unexpected error opening overlay settings: $e');
      }
    }
  }

  /*
  /// Opens accessibility settings directly
  static Future<void> openAccessibilitySettings() async {
    if (Platform.isAndroid) {
      await openSystemSettings('android.settings.ACCESSIBILITY_SETTINGS');
    }
  }
  */

  /// Check if overlay permission is granted
  static Future<bool> checkOverlayPermission() async {
    try {
      final bool isGranted = await _channel.invokeMethod('checkOverlayPermission');
      return isGranted;
    } on PlatformException catch (e) {
      print('Failed to check overlay permission: ${e.message}');
      return false;
    }
  }

  /*
  /// Check if accessibility permission is granted
  static Future<bool> checkAccessibilityPermission() async {
    try {
      final bool isGranted = await _channel.invokeMethod('checkAccessibilityPermission');
      return isGranted;
    } on PlatformException catch (e) {
      print('Failed to check accessibility permission: ${e.message}');
      return false;
    }
  }
  */
  
  /// Scrape a LinkedIn post using the backend API
  static Future<Map<String, dynamic>> scrapeLinkedInPost(String url) async {
    try {
      // Initialize the API service if needed
      await _apiService.init();
      
      // Use the API service to scrape the LinkedIn post
      return await _apiService.scrapeLinkedInPost(url);
    } catch (e) {
      print('Failed to scrape LinkedIn post: $e');
      return {
        'content': 'Failed to scrape LinkedIn post: $e',
        'author': 'Error',
        'date': 'Now',
        'likes': 0,
        'comments': 0,
        'images': <String>[],
        'commentsList': <Map<String, String>>[]
      };
    }
  }
  
  /// Get LinkedIn OEmbed data for a post URL
  static Future<Map<String, dynamic>> getLinkedInOEmbedData(String url) async {
    try {
      // Use the LinkedIn service to get OEmbed data
      return await _linkedInService.getLinkedInOEmbedData(url);
    } catch (e) {
      print('Failed to get LinkedIn OEmbed data: $e');
      return {
        'success': false,
        'error': 'Failed to get LinkedIn OEmbed data: $e',
        'html': null
      };
    }
  }
  
  /// Generate a summary of LinkedIn post content
  static Future<Map<String, dynamic>> generateSummary(String content, String author, String summaryType) async {
    try {
      // Import the LinkedIn service here to avoid circular imports
      final linkedInService = LinkedInService();
      
      // Call the LinkedIn service to generate a summary
      final result = await linkedInService.generateSummary(
        content: content,
        author: author,
        summaryType: summaryType,
      );
      
      return result;
    } catch (e) {
      print('Failed to generate summary: $e');
      return {
        'summary': 'Failed to generate summary: $e',
        'error': e.toString(),
      };
    }
  }
  
  /// Show the overlay
  static Future<bool> showOverlay() async {
    try {
      final bool success = await _overlayChannel.invokeMethod('showOverlay');
      return success;
    } on PlatformException catch (e) {
      print('Failed to show overlay: ${e.message}');
      return false;
    }
  }
  
  /// Hide the overlay
  static Future<bool> hideOverlay() async {
    try {
      final bool success = await _overlayChannel.invokeMethod('hideOverlay');
      return success;
    } on PlatformException catch (e) {
      print('Failed to hide overlay: ${e.message}');
      return false;
    }
  }

  /// Launches native OverlayPermissionActivity for overlay permission
  static Future<void> openOverlayPermissionActivity() async {
    try {
      await _platformChannel.invokeMethod('openOverlayPermissionActivity');
    } on PlatformException catch (e) {
      print('Failed to open overlay permission activity: ${e.message}');
      rethrow;
    }
  }
}