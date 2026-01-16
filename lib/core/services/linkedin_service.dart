import 'dart:async';
import 'social_platform_service.dart';

/// @deprecated Use [SocialPlatformService] instead.
/// This class is kept for backward compatibility and forwards all calls to SocialPlatformService.
@Deprecated('Use SocialPlatformService instead')
class LinkedInService {
  static final LinkedInService _instance = LinkedInService._internal();
  final SocialPlatformService _socialService = SocialPlatformService();
  
  /// Singleton instance
  factory LinkedInService() {
    return _instance;
  }

  LinkedInService._internal();
  
  /// Comment button types available in the app
  static List<String> get commentButtonTypes => SocialPlatformService.commentButtonTypes;
  
  /// Post frameworks available
  static List<String> get postFrameworks => SocialPlatformService.postFrameworks;
  
  /// Languages available for translation
  static List<Map<String, String>> get availableLanguages => SocialPlatformService.availableLanguages;
  
  /// Get the user's preferred framework for posts
  Future<String> getPreferredFramework() => _socialService.getPreferredFramework();
  
  /// Set the user's preferred framework for posts
  Future<void> setPreferredFramework(String framework) => _socialService.setPreferredFramework(framework);

  /// Get whether to include hashtags in generated posts
  Future<bool> getIncludeHashtags() => _socialService.getIncludeHashtags();
  
  /// Set whether to include hashtags in generated posts
  Future<void> setIncludeHashtags(bool include) => _socialService.setIncludeHashtags(include);
  
  /// Get whether to include emojis in generated content
  Future<bool> getIncludeEmojis() => _socialService.getIncludeEmojis();
  
  /// Set whether to include emojis in generated content
  Future<void> setIncludeEmojis(bool include) => _socialService.setIncludeEmojis(include);

  /// Generate a comment for a post based on the button type
  Future<String> generateComment({
    required String postContent,
    required String author,
    required String commentType,
    String? imageUrl,
  }) => _socialService.generateComment(
    postContent: postContent,
    author: author,
    commentType: commentType,
    imageUrl: imageUrl,
  );
  
  /// Generate a personalized comment with specific tone and details
  Future<String> generatePersonalizedComment({
    required String postContent,
    required String author,
    required String tone,
    required String toneDetails,
    String? imageUrl,
    String? buttonType,
    String? existingComment,
  }) => _socialService.generatePersonalizedComment(
    postContent: postContent,
    author: author,
    tone: tone,
    toneDetails: toneDetails,
    imageUrl: imageUrl,
    buttonType: buttonType,
    existingComment: existingComment,
  );

  /// Generate a post with AI
  Future<String> generatePost({
    required String prompt,
    String? framework,
    String? tone,
    String? toneDetails,
  }) => _socialService.generatePost(
    prompt: prompt,
    framework: framework,
    tone: tone,
    toneDetails: toneDetails,
  );
  
  /// Generate or modify an About section
  Future<String> generateAboutSection({
    required String currentAbout,
    required String buttonType,
    String? company,
    String? experience,
    String? toneDetails,
  }) => _socialService.generateAboutSection(
    currentAbout: currentAbout,
    buttonType: buttonType,
    company: company,
    experience: experience,
    toneDetails: toneDetails,
  );
  
  /// Generate a connection request note
  Future<String> generateConnectionNote({
    required String profileName,
    required String about,
    String? mutual,
    String? buttonType,
    String? tone,
    String? toneDetails,
    String? existingMessage,
  }) => _socialService.generateConnectionNote(
    profileName: profileName,
    about: about,
    mutual: mutual,
    buttonType: buttonType,
    tone: tone,
    toneDetails: toneDetails,
    existingMessage: existingMessage,
  );
  
  /// Translate content to a different language
  Future<Map<String, dynamic>> translateContent({
    required String content,
    required String targetLanguage,
    String? author,
    bool formatForDisplay = false,
  }) => _socialService.translateContent(
    content: content,
    targetLanguage: targetLanguage,
    author: author,
    formatForDisplay: formatForDisplay,
  );
  
  /// Generate summary of post content
  Future<Map<String, dynamic>> generateSummary({
    required String content,
    required String author,
    String summaryType = 'concise',
  }) => _socialService.generateSummary(
    content: content,
    author: author,
    summaryType: summaryType,
  );
  
  /// Correct grammar in the given text
  Future<String> correctGrammar(String text) => _socialService.correctGrammar(text);
  
  /// Save a profile
  Future<bool> saveProfile({
    required String name,
    required String title,
    required String about,
    required String url,
    String? mutual,
  }) => _socialService.saveProfile(
    name: name,
    title: title,
    about: about,
    url: url,
    mutual: mutual,
  );

  /// @deprecated Use [SocialPlatformService.getOEmbedData] instead.
  /// Fetch OEmbed data for a given post URL
  Future<Map<String, dynamic>> getLinkedInOEmbedData(String postUrl) => 
    _socialService.getOEmbedData(postUrl);
} 