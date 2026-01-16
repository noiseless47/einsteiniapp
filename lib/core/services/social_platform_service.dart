import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html_unescape/html_unescape.dart';

/// Social platform service class to handle social media operations (LinkedIn, X/Twitter, etc.)
class SocialPlatformService {
  static final SocialPlatformService _instance = SocialPlatformService._internal();
  final ApiService _apiService = ApiService();
  final HtmlUnescape _htmlUnescape = HtmlUnescape();
  
  /// Singleton instance
  factory SocialPlatformService() {
    return _instance;
  }

  SocialPlatformService._internal();
  
  /// Comment button types available in the app
  static const List<String> commentButtonTypes = [
    'Agree',    // Short, agreeing comment
    'Expand',   // Longer, more detailed comment
    'Fun',      // Humorous or entertaining comment
    'AI Rectify', // Grammar correction
    'Question',   // Ask a question
    'Perspective', // Different perspective
    'Personalize', // Personalized comment
    'Translate'    // Translate content
  ];
  
  /// Post frameworks available
  static const List<String> postFrameworks = [
    'AIDA',    // Attention, Interest, Desire, Action
    'HAS',     // Hook, Amplify, Story
    'FAB',     // Features, Advantages, Benefits
    'STAR',    // Situation, Task, Action, Result
  ];
  
  /// Languages available for translation
  static const List<Map<String, String>> availableLanguages = [
    {'code': 'arabic', 'name': 'Arabic'},
    {'code': 'dutch', 'name': 'Dutch'},
    {'code': 'english', 'name': 'English'},
    {'code': 'french', 'name': 'French'},
    {'code': 'german', 'name': 'German'},
    {'code': 'hindi', 'name': 'Hindi'},
    {'code': 'italian', 'name': 'Italian'},
    {'code': 'japanese', 'name': 'Japanese'},
    {'code': 'kannada', 'name': 'Kannada'},
    {'code': 'mandarin', 'name': 'Mandarin'},
    {'code': 'punjabi', 'name': 'Punjabi'},
    {'code': 'russian', 'name': 'Russian'},
    {'code': 'spanish', 'name': 'Spanish'},
  ];
  
  /// Get the user's preferred framework for posts
  Future<String> getPreferredFramework() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_framework') ?? 'AIDA';
  }
  
  /// Set the user's preferred framework for posts
  Future<void> setPreferredFramework(String framework) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_framework', framework);
  }

  /// Get whether to include hashtags in generated posts
  Future<bool> getIncludeHashtags() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('include_hashtags') ?? true;
  }
  
  /// Set whether to include hashtags in generated posts
  Future<void> setIncludeHashtags(bool include) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('include_hashtags', include);
  }
  
  /// Get whether to include emojis in generated content
  Future<bool> getIncludeEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('include_emojis') ?? true;
  }
  
  /// Set whether to include emojis in generated content
  Future<void> setIncludeEmojis(bool include) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('include_emojis', include);
  }

  /// Generate a comment for a social media post based on the button type
  Future<String> generateComment({
    required String postContent,
    required String author,
    required String commentType,
    String? imageUrl,
  }) async {
    return await _apiService.generateComment(
      postContent: postContent,
      author: author,
      commentType: commentType,
      imageUrl: imageUrl,
    );
  }
  
  /// Generate a personalized comment with specific tone and details
  Future<String> generatePersonalizedComment({
    required String postContent,
    required String author,
    required String tone,
    required String toneDetails,
    String? imageUrl,
    String? buttonType,
    String? existingComment,
  }) async {
    // Use the dedicated personalized comment API method
    return await _apiService.generatePersonalizedComment(
      postContent: postContent,
      author: author,
      tone: tone,
      toneDetails: toneDetails,
      imageUrl: imageUrl,
    );
  }

  /// Generate a social media post with AI
  Future<String> generatePost({
    required String prompt,
    String? framework,
    String? tone,
    String? toneDetails,
  }) async {
    // If framework is not provided, use the user's preferred framework
    final actualFramework = framework ?? await getPreferredFramework();
    
    return await _apiService.generatePost(
      prompt: prompt,
      framework: actualFramework,
      tone: tone,
      toneDetails: toneDetails,
    );
  }
  
  /// Generate or modify a profile About section
  Future<String> generateAboutSection({
    required String currentAbout,
    required String buttonType,
    String? company,
    String? experience,
    String? toneDetails,
  }) async {
    return await _apiService.generateAbout(
      currentAbout: currentAbout,
      type: buttonType,
      company: company,
      experience: experience,
      toneDetails: toneDetails,
    );
  }
  
  /// Generate a connection request note
  Future<String> generateConnectionNote({
    required String profileName,
    required String about,
    String? mutual,
    String? buttonType,
    String? tone,
    String? toneDetails,
    String? existingMessage,
  }) async {
    return await _apiService.generateConnectionNote(
      profileName: profileName,
      about: about,
      mutual: mutual,
      buttonType: buttonType,
      tone: tone,
      toneDetails: toneDetails,
      message: existingMessage,
    );
  }
  
  /// Translate content to a different language
  Future<Map<String, dynamic>> translateContent({
    required String content,
    required String targetLanguage,
    String? author,
    bool formatForDisplay = false,
  }) async {
    try {
      // Handle default language case
      if (targetLanguage.toLowerCase() == 'default') {
        return {
          'translation': 'Please select a language',
          'language': targetLanguage,
          'error': 'No language selected'
        };
      }
      
      final result = await _apiService.translateContent(
        content: content,
        language: targetLanguage,
        author: author,
      );
      
      // Check for errors in the API response
      if (result.containsKey('error')) {
        debugPrint('Translation error detected: ${result['error']}');
        return {
          'translation': result['translation'] ?? 'Translation error',
          'formattedTranslation': result['translation'] ?? 'Translation error',
          'language': targetLanguage,
          'error': result['error']
        };
      }
      
      final translation = result['translation'] ?? 'Translation error';
      
      // Format the translation with paragraph breaks for better readability
      String formattedTranslation = translation;
      if (!formattedTranslation.contains('\n')) {
        // Break into paragraphs for readability (approximately 3 sentences per paragraph)
        final RegExp sentenceBreak = RegExp(r'(?<=[.!?])\s');
        final List<String> sentences = formattedTranslation.split(sentenceBreak);
        
        if (sentences.length > 3) {
          StringBuffer paragraphBuilder = StringBuffer();
          List<String> paragraphs = [];
          
          for (int i = 0; i < sentences.length; i++) {
            paragraphBuilder.write(sentences[i]);
            paragraphBuilder.write(' ');
            
            if ((i + 1) % 3 == 0 && i < sentences.length - 1) {
              paragraphs.add(paragraphBuilder.toString().trim());
              paragraphBuilder = StringBuffer();
            }
          }
          
          if (paragraphBuilder.isNotEmpty) {
            paragraphs.add(paragraphBuilder.toString().trim());
          }
          
          formattedTranslation = paragraphs.join('\n\n');
        }
      }
      
      return {
        'translation': translation,
        'formattedTranslation': formattedTranslation,
        'language': targetLanguage
      };
    } catch (e) {
      debugPrint('Exception in translateContent: $e');
      return {
        'translation': 'Error: Translation failed',
        'formattedTranslation': 'Error: Translation failed',
        'language': targetLanguage,
        'error': e.toString()
      };
    }
  }
  
  /// Generate summary of social post content
  Future<Map<String, dynamic>> generateSummary({
    required String content,
    required String author,
    String summaryType = 'concise',
  }) async {
    try {
      final result = await _apiService.generateSummary(
        content: content,
        author: author,
        summaryType: summaryType,
      );
      
      // Check for errors in the API response
      if (result.containsKey('error')) {
        debugPrint('Summary generation error detected: ${result['error']}');
        return {
          'summary': result['summary'] ?? 'Summary generation error',
          'error': result['error']
        };
      }
      
      final summary = result['summary'] ?? 'Summary generation error';
      
      return {
        'summary': summary,
        'keyPoints': result['keyPoints'] ?? [],
        'summaryType': summaryType
      };
    } catch (e) {
      debugPrint('Exception in generateSummary: $e');
      return {
        'summary': 'Error: Summary generation failed',
        'error': e.toString()
      };
    }
  }
  
  /// Correct grammar in the given text
  Future<String> correctGrammar(String text) async {
    return await _apiService.correctGrammar(text);
  }
  
  /// Save a social profile
  Future<bool> saveProfile({
    required String name,
    required String title,
    required String about,
    required String url,
    String? mutual,
  }) async {
    return await _apiService.saveProfile(
      name: name,
      title: title,
      about: about,
      url: url,
      mutual: mutual,
    );
  }

  /// Fetch OEmbed data for a given post URL (supports LinkedIn, X/Twitter)
  /// Returns a map with the necessary data to display the post
  Future<Map<String, dynamic>> getOEmbedData(String postUrl) async {
    try {
      debugPrint('Fetching OEmbed data for: $postUrl');
      
      // Check if the URL is a supported social platform URL
      final isLinkedIn = postUrl.contains('linkedin.com');
      final isTwitter = postUrl.contains('twitter.com') || postUrl.contains('x.com');
      
      if (!isLinkedIn && !isTwitter) {
        return {
          'success': false,
          'error': 'Not a valid social platform URL',
          'html': null,
        };
      }
      
      // Use backend proxy for OEmbed
      final response = await http.get(
        Uri.parse('https://backend.einsteini.ai/oembed?url=${Uri.encodeComponent(postUrl)}'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data is Map && data.containsKey('html')) {
          // Unescape HTML entities in the response
          final String html = _htmlUnescape.convert(data['html'].toString());
          
          return {
            'success': true,
            'html': html,
            'title': data['title'] ?? 'Social Post',
            'author_name': data['author_name'] ?? 'User',
            'provider_name': data['provider_name'] ?? 'Social Platform',
          };
        }
        
        // If our backend doesn't return proper OEmbed format
        return {
          'success': true,
          'html': _generateEmbedHtml(postUrl),
          'title': 'Social Post',
          'author_name': 'User',
          'provider_name': 'Social Platform',
        };
      } else {
        // Fallback: Generate our own embed HTML
        return {
          'success': true,
          'html': _generateEmbedHtml(postUrl),
          'title': 'Social Post',
          'author_name': 'User',
          'provider_name': 'Social Platform',
        };
      }
    } catch (e) {
      debugPrint('Error fetching OEmbed data: $e');
      
      // Fallback: Generate our own embed HTML
      return {
        'success': true,
        'html': _generateEmbedHtml(postUrl),
        'title': 'Social Post',
        'author_name': 'User',
        'provider_name': 'Social Platform',
      };
    }
  }
  
  /// Generate embed HTML for social posts
  String _generateEmbedHtml(String postUrl) {
    // Create a responsive iframe that will work in a WebView
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
          .container { width: 100%; height: 100%; overflow: hidden; }
          iframe { width: 100%; height: 100%; border: none; }
          .linkedin-embed { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%; }
          .linkedin-embed iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="linkedin-embed">
            <iframe src="$postUrl" frameborder="0" allowfullscreen scrolling="no"></iframe>
          </div>
        </div>
      </body>
      </html>
    ''';
  }
} 