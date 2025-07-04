import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:einsteiniapp/core/utils/toast_utils.dart';
import 'package:einsteiniapp/core/utils/platform_channel.dart';
import 'package:einsteiniapp/core/services/history_service.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:einsteiniapp/core/services/linkedin_service.dart';

class AIAssistantTab extends StatefulWidget {
  const AIAssistantTab({Key? key}) : super(key: key);

  @override
  AIAssistantTabState createState() => AIAssistantTabState();
}

class AIAssistantTabState extends State<AIAssistantTab> with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;
  
  // Link input controller
  final TextEditingController _linkController = TextEditingController();
  
  // Post creation controllers
  final TextEditingController _postTopicController = TextEditingController();
  final TextEditingController _postToneController = TextEditingController();
  final TextEditingController _postLengthController = TextEditingController();
  
  // Summary controller
  final TextEditingController _summaryTypeController = TextEditingController();
  
  // Translation controller
  final TextEditingController _translationLanguageController = TextEditingController();
  
  // Comment controller
  final TextEditingController _commentToneController = TextEditingController();
  
  // About Me controllers
  final TextEditingController _industryController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _aboutToneController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  bool _hasAnalyzedContent = false;
  String _errorMessage = '';
  
  // Post content
  String _postContent = '';
  String _postAuthor = '';
  String _postDate = '';
  String _postUrl = '';
  int _likes = 0;
  int _comments = 0;
  List<String> _postImages = [];
  List<Map<String, String>> _commentsList = [];
  
  // Generated content
  String _selectedOption = '';
  String _summary = '';
  String _translation = '';
  String _generatedComment = '';
  String _generatedPost = '';
  String _generatedAboutMe = '';
  
  // Generation states
  bool _isGeneratingComment = false;
  bool _isGeneratingPost = false;
  bool _isGeneratingAboutMe = false;
  
  // Lists of options
  static const List<String> _availableLanguages = [
    'Default', 'English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese',
    'Russian', 'Arabic', 'Portuguese', 'Italian', 'Hindi', 'Dutch'
  ];
  
  static const List<String> _availableCommentTones = [
    'Professional', 'Friendly', 'Enthusiastic', 'Thoughtful', 'Questioning', 'Supportive'
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Add listener to handle tab changes
    _tabController.addListener(_handleTabChange);
    
    // Set some default values
    _postToneController.text = 'Professional';
    _postLengthController.text = 'Medium';
    
    // Set default values for new controllers
    _summaryTypeController.text = 'Concise';
    _translationLanguageController.text = 'English';
    _commentToneController.text = 'Professional';
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _linkController.dispose();
    _postTopicController.dispose();
    _postToneController.dispose();
    _postLengthController.dispose();
    _industryController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _goalController.dispose();
    _summaryTypeController.dispose();
    _translationLanguageController.dispose();
    _commentToneController.dispose();
    _aboutToneController.dispose();
    super.dispose();
  }
  
  // Handle tab changes to ensure clean transitions
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        // Any state reset needed when changing tabs
      });
    }
  }
  
  // Method to set tab index from outside
  void setTabIndex(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  Future<void> _analyzeLinkedInPost() async {
    final link = _linkController.text.trim();
    _postUrl = link;
    
    if (link.isEmpty) {
      ToastUtils.showErrorToast('Please enter a LinkedIn post URL');
      return;
    }
    
    if (!link.contains('linkedin.com')) {
      ToastUtils.showErrorToast('Please enter a valid LinkedIn URL');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Use the backend API to extract content from the LinkedIn post
      final scrapedData = await PlatformChannel.scrapeLinkedInPost(link);
      
      setState(() {
        _isLoading = false;
        _hasAnalyzedContent = true;
        _postContent = scrapedData['content'] ?? 'No content found';
        _postAuthor = scrapedData['author'] ?? 'Unknown author';
        _postDate = scrapedData['date'] ?? 'Unknown date';
        _likes = scrapedData['likes'] ?? 0;
        _comments = scrapedData['comments'] ?? 0;
        _postImages = scrapedData['images'] ?? [];
        _commentsList = (scrapedData['commentsList'] as List<dynamic>?)?.cast<Map<String, String>>() ?? [];
        
        // Check if there was an error in scraping
        if (_postContent.contains('Failed to scrape LinkedIn post') || 
            _postContent.contains('Error:') || 
            _postContent.contains('Network or server issue')) {
          _errorMessage = _postContent;
          _postContent = 'Unable to retrieve LinkedIn post content. This may be due to LinkedIn\'s security measures or the post\'s privacy settings.';
        }
        
        // Don't automatically generate summary or translation
        // Just navigate to the selected option screen
      });
      
      // Save to history
      _saveToHistory();
      
      if (_errorMessage.isEmpty) {
      ToastUtils.showSuccessToast('Post analyzed successfully');
      } else {
        ToastUtils.showErrorToast('Post analysis incomplete: Some content may be missing');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      ToastUtils.showErrorToast('Error analyzing post: $e');
    }
  }
  
  void _saveToHistory() async {
    try {
      // Generate a title from the content
      final title = AnalyzedPost.generateTitleFromContent(_postContent);
      
      // Create an analyzed post object
      final analyzedPost = AnalyzedPost(
        id: const Uuid().v4(),
        title: title,
        content: _postContent,
        author: _postAuthor,
        date: _postDate,
        analyzedAt: DateTime.now().toIso8601String(),
        postUrl: _postUrl,
        likes: _likes,
        comments: _comments,
        images: _postImages,
        commentsList: _commentsList,
        functionality: 'analyze', // Default functionality is analysis
      );
      
      // Save to history
      await HistoryService.savePost(analyzedPost);
    } catch (e) {
      print('Error saving to history: $e');
    }
  }
  
  // Save to history with summary functionality
  void _saveToHistoryWithSummary() async {
    try {
      // Generate a title from the content
      final title = AnalyzedPost.generateTitleFromContent(_postContent);
      
      // Create an analyzed post object with summary functionality
      final analyzedPost = AnalyzedPost(
        id: const Uuid().v4(),
        title: title,
        content: _postContent,
        author: _postAuthor,
        date: _postDate,
        analyzedAt: DateTime.now().toIso8601String(),
        postUrl: _postUrl,
        likes: _likes,
        comments: _comments,
        images: _postImages,
        commentsList: _commentsList,
        functionality: 'summary: ${_summaryTypeController.text}', // Specify summary type
      );
      
      // Save to history
      await HistoryService.savePost(analyzedPost);
    } catch (e) {
      print('Error saving summary to history: $e');
    }
  }
  
  // Save to history with translation functionality
  void _saveToHistoryWithTranslation() async {
    try {
      // Generate a title from the content
      final title = AnalyzedPost.generateTitleFromContent(_postContent);
      
      // Create an analyzed post object with translation functionality
      final analyzedPost = AnalyzedPost(
        id: const Uuid().v4(),
        title: title,
        content: _postContent,
        author: _postAuthor,
        date: _postDate,
        analyzedAt: DateTime.now().toIso8601String(),
        postUrl: _postUrl,
        likes: _likes,
        comments: _comments,
        images: _postImages,
        commentsList: _commentsList,
        functionality: 'translate: ${_translationLanguageController.text}', // Specify language
      );
      
      // Save to history
      await HistoryService.savePost(analyzedPost);
    } catch (e) {
      print('Error saving translation to history: $e');
    }
  }
  
  // Save to history with comment functionality
  void _saveToHistoryWithComment() async {
    try {
      // Generate a title from the content
      final title = AnalyzedPost.generateTitleFromContent(_postContent);
      
      // Create an analyzed post object with comment functionality
      final analyzedPost = AnalyzedPost(
        id: const Uuid().v4(),
        title: title,
        content: _postContent,
        author: _postAuthor,
        date: _postDate,
        analyzedAt: DateTime.now().toIso8601String(),
        postUrl: _postUrl,
        likes: _likes,
        comments: _comments,
        images: _postImages,
        commentsList: _commentsList,
        functionality: 'comment: ${_commentToneController.text}', // Specify comment tone
      );
      
      // Save to history
      await HistoryService.savePost(analyzedPost);
    } catch (e) {
      print('Error saving comment to history: $e');
    }
  }
  
  Future<void> analyzeFromHistory(AnalyzedPost post) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Set the URL in the text field
      _linkController.text = post.postUrl;
      
      // Re-analyze the post
      await _analyzeLinkedInPost();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ToastUtils.showErrorToast('Error re-analyzing post: $e');
    }
  }
  
  void _clearAnalysis() {
    setState(() {
      _hasAnalyzedContent = false;
      _postContent = '';
      _postAuthor = '';
      _postDate = '';
      _likes = 0;
      _comments = 0;
      _postImages = [];
      _commentsList = [];
      _postUrl = '';
      _errorMessage = '';
      _linkController.clear();
      _selectedOption = '';
      _summary = '';
      _translation = '';
    });
  }
  
  void _selectOption(String option) {
    setState(() {
      _selectedOption = option;
      
      // Remove automatic generation - let the user click the generate button
    });
  }
  
  void _generateSummary() async {
    if (_postContent.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use the LinkedInService to perform the actual summarization
      final linkedInService = LinkedInService();
      final result = await linkedInService.generateSummary(
        content: _postContent,
        author: _postAuthor,
        summaryType: _summaryTypeController.text.toLowerCase(),
      );
      
      if (result.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _summary = result['summary'] ?? 'Summary generation temporarily unavailable. Please try again later.';
        });
        ToastUtils.showErrorToast('Summary generation failed. Please try again later.');
        return;
      }
      
      // Format the key points if available
      String keyPointsText = '';
      if (result.containsKey('keyPoints') && (result['keyPoints'] as List).isNotEmpty) {
        keyPointsText = '\n\nKey points:\n';
        for (final point in result['keyPoints'] as List) {
          keyPointsText += '- $point\n';
        }
      }
      
      setState(() {
        _isLoading = false;
        _summary = result['summary'] + keyPointsText;
      });
      
      // Save to history with summary functionality
      _saveToHistoryWithSummary();
      
      ToastUtils.showSuccessToast('Summary generated successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _summary = 'Summary generation temporarily unavailable. Please try again later.';
      });
      ToastUtils.showErrorToast('Error generating summary. Please try again later.');
    }
  }
  
  void _generateTranslation() async {
    if (_postContent.isEmpty) {
      return;
    }
    
    // Don't translate if language is Default
    if (_translationLanguageController.text == 'Default') {
      setState(() {
        _translation = '';
        _isLoading = false;
      });
      ToastUtils.showErrorToast('Please select a language');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use the LinkedInService to perform the actual translation
      final linkedInService = LinkedInService();
      final result = await linkedInService.translateContent(
        content: _postContent,
        targetLanguage: _translationLanguageController.text.toLowerCase(),
        author: _postAuthor,
        formatForDisplay: true,
      );
      
      if (result.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _translation = 'Error translating content: ${result['error']}';
        });
        ToastUtils.showErrorToast('Translation failed. Please try again.');
        return;
      }
      
      setState(() {
        _isLoading = false;
        _translation = result['formattedTranslation'] ?? result['translation'] ?? 'Translation error';
      });
      
      // Save to history with translation functionality
      _saveToHistoryWithTranslation();
      
      ToastUtils.showSuccessToast('Translation generated successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _translation = 'Error translating content: $e';
      });
      ToastUtils.showErrorToast('Error translating content: $e');
    }
  }
  
  void _switchToCommentMode() {
    setState(() {
      _selectedOption = 'comment';
    });
  }
  
  // Generate a new post based on input
  void _generatePost() {
    if (_postTopicController.text.isEmpty) {
      ToastUtils.showErrorToast('Please enter a topic for your post');
      return;
    }
    
    setState(() {
      _isGeneratingPost = true;
    });
    
    // Simulate API call delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGeneratingPost = false;
        _generatedPost = '''
Looking to transform your ${_postTopicController.text.toLowerCase()} strategy? Here's what I've found works exceptionally well:

1️⃣ Consistently invest in quality over quantity
2️⃣ Listen carefully to customer feedback and adapt quickly
3️⃣ Build relationships before focusing on transactions
4️⃣ Leverage data-driven insights for decision making

I've seen companies increase their ROI by over 40% using these principles. The key is persistence and authentic connection with your audience.

What strategies have worked well for you in the ${_postTopicController.text.toLowerCase()} space? Share your thoughts below!

#${_postTopicController.text.replaceAll(' ', '')} #ProfessionalGrowth #Leadership
''';
      });
      ToastUtils.showSuccessToast('Post generated successfully');
    });
  }
  
  // Generate an About Me section based on input
  void _generateAboutMe() {
    if (_industryController.text.isEmpty || _experienceController.text.isEmpty || 
        _skillsController.text.isEmpty || _goalController.text.isEmpty) {
      ToastUtils.showErrorToast('Please fill in all fields');
      return;
    }
    
    setState(() {
      _isGeneratingAboutMe = true;
    });
    
    // Simulate API call delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGeneratingAboutMe = false;
        _generatedAboutMe = '''
👋 Results-driven ${_industryController.text} professional with ${_experienceController.text} of experience driving strategic initiatives and delivering measurable outcomes.

💼 My expertise includes ${_skillsController.text}, with a proven track record of helping organizations achieve their business objectives through innovative solutions.

🚀 Passionate about ${_goalController.text}, I combine analytical thinking with creative problem-solving to tackle complex challenges.

💡 I thrive in collaborative environments and enjoy mentoring teams to reach their full potential. Always seeking opportunities to learn, grow, and make an impact.

🔗 Let's connect to explore how we might work together to achieve remarkable results!
''';
      });
      ToastUtils.showSuccessToast('About Me generated successfully');
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.end,
        children: [
            TabBar(
              tabs: const [
                Tab(text: 'Analyze Post'),
                Tab(text: 'Create Post'),
                Tab(text: 'About Me'),
              ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                indicatorColor: Theme.of(context).colorScheme.primary,
                dividerColor: Colors.transparent,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Analyze LinkedIn Post Tab
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildLinkedInAnalysisTab(),
              ),
            ),
            
            // Create LinkedIn Post Tab
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildCreatePostTab(),
              ),
            ),
            
            // About Me Tab
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildAboutMeTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // LinkedIn Analysis Tab
  Widget _buildLinkedInAnalysisTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLinkInputSection(),
          
          const SizedBox(height: 24),
          
          if (_isLoading) 
            _buildLoadingIndicator()
          else if (_hasAnalyzedContent) 
            _buildContentBasedOnSelection()
          else
            _buildEmptyState(),
        ],
      ),
    );
  }
  
  Widget _buildContentBasedOnSelection() {
    if (_selectedOption.isEmpty) {
      return _buildAnalyzedContent();
    } else if (_selectedOption == 'summarize') {
      return _buildSummarizeContent();
    } else if (_selectedOption == 'translate') {
      return _buildTranslateContent();
    } else if (_selectedOption == 'comment') {
      return _buildCommentContent();
    }
    return _buildAnalyzedContent();
  }
  
  // Create Post Tab
  Widget _buildCreatePostTab() {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create AI-Powered LinkedIn Posts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Enter details below to generate engaging LinkedIn posts',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        
        const SizedBox(height: 24),
        
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: keyboardVisible ? 200 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic input
              _buildInputField(
                label: 'Post Topic',
                hintText: 'e.g., Digital Marketing, Leadership, Tech Trends',
                controller: _postTopicController,
                icon: Icons.topic,
              ),
              
              const SizedBox(height: 16),
              
              // Tone selection
              _buildDropdownField(
                label: 'Content Tone',
                hintText: 'Select the tone for your post',
                controller: _postToneController,
                icon: Icons.mood,
                options: ['Professional', 'Friendly', 'Inspirational', 'Educational', 'Thought-Provoking'],
              ),
              
              const SizedBox(height: 16),
              
              // Length selection
              _buildDropdownField(
                label: 'Post Length',
                hintText: 'Select the length of your post',
                controller: _postLengthController,
                icon: Icons.format_size,
                options: ['Short', 'Medium', 'Long'],
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGeneratingPost ? null : _generatePost,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isGeneratingPost
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate Post'),
                ),
              ),
              
              if (_generatedPost.isNotEmpty) ...[
                const SizedBox(height: 24),
                
                // Generated post
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              radius: 16,
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI-Generated Post',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          _generatedPost,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedPost)).then((_) {
                                  ToastUtils.showSuccessToast('Post copied to clipboard');
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                            ),
                            
                            ElevatedButton.icon(
                              onPressed: () {
                                // In a real app, this would open the LinkedIn app with the post pre-filled
                                ToastUtils.showInfoToast('This would open LinkedIn with this post');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                iconColor: Colors.white, // Explicitly set icon color
                              ),
                              icon: const Icon(Icons.send, size: 16, color: Colors.white),
                              label: const Text('Post to LinkedIn'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        OutlinedButton.icon(
                          onPressed: _generatePost,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Generate Another Version'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  // About Me Tab
  Widget _buildAboutMeTab() {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your LinkedIn About Me',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Provide information to generate a professional LinkedIn summary',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        
        const SizedBox(height: 24),
        
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: keyboardVisible ? 200 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Industry input
              _buildInputField(
                label: 'Your Industry',
                hintText: 'e.g., Software Development, Marketing, Finance',
                controller: _industryController,
                icon: Icons.business,
              ),
              
              const SizedBox(height: 16),
              
              // Experience input
              _buildInputField(
                label: 'Years of Experience',
                hintText: 'e.g., 5+ years, 10+ years',
                controller: _experienceController,
                icon: Icons.work,
              ),
              
              const SizedBox(height: 16),
              
              // Skills input
              _buildInputField(
                label: 'Key Skills',
                hintText: 'e.g., Project Management, Data Analysis, Leadership',
                controller: _skillsController,
                icon: Icons.psychology,
              ),
              
              const SizedBox(height: 16),
              
              // Goal input
              _buildInputField(
                label: 'Professional Goal',
                hintText: 'e.g., Driving innovation, Building high-performance teams',
                controller: _goalController,
                icon: Icons.emoji_events,
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGeneratingAboutMe ? null : _generateAboutMe,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isGeneratingAboutMe
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate About Me'),
                ),
              ),
              
              if (_generatedAboutMe.isNotEmpty) ...[
                const SizedBox(height: 24),
                
                // Generated About Me
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              radius: 16,
                              child: const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI-Generated About Me',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          _generatedAboutMe,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedAboutMe)).then((_) {
                                  ToastUtils.showSuccessToast('About Me copied to clipboard');
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                            ),
                            
                            ElevatedButton.icon(
                              onPressed: () {
                                // In a real app, this would open the LinkedIn app to update profile
                                ToastUtils.showInfoToast('This would open your LinkedIn profile');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Update Profile'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        OutlinedButton.icon(
                          onPressed: _generateAboutMe,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Generate Another Version'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper widget for input fields
  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                border: InputBorder.none,
                filled: false,
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper widget for dropdown fields
  Widget _buildDropdownField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    required List<String> options,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          CustomDropdownField(
            labelText: label,
            controller: controller,
            onTap: () {
              _showOptionsBottomSheet(context, label, options, controller);
            },
          ),
        ],
      ),
    );
  }
  
  void _showOptionsBottomSheet(
    BuildContext context,
    String title,
    List<String> options,
    TextEditingController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select $title',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            const Divider(),
            
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = controller.text == option;
                  
                  return InkWell(
                    onTap: () {
                      // Update controller text
                      controller.text = option;
                      
                      // Close bottom sheet
                      Navigator.pop(context);
                      
                      // Update the parent state to refresh UI immediately
                      setState(() {
                        // The setState call forces the UI to rebuild with the new value
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLinkInputSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LinkedIn Post URL',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Row(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: 'https://www.linkedin.com/posts/...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  suffixIcon: _linkController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _linkController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _analyzeLinkedInPost(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            
            const SizedBox(width: 12),
            
            ElevatedButton(
              onPressed: _linkController.text.isNotEmpty ? _analyzeLinkedInPost : null,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                  minimumSize: const Size(90, 48),
              ),
              child: const Text('Analyze'),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                // Paste from clipboard
                Clipboard.getData(Clipboard.kTextPlain).then((value) {
                  if (value != null && value.text != null) {
                    _linkController.text = value.text!;
                    setState(() {});
                  }
                });
              },
              icon: const Icon(Icons.paste, size: 16),
              label: const Text('Paste from clipboard'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ),
          ],
        ),
      ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Analyzing LinkedIn post...',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      height: 400,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No LinkedIn post analyzed yet',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Enter a LinkedIn post URL above to get started',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyzedContent() {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
            'What would you like to do with this post?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  title: 'Summarize',
                  icon: Icons.summarize,
                  onTap: () => _selectOption('summarize'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOptionButton(
                  title: 'Translate',
                  icon: Icons.translate,
                  onTap: () => _selectOption('translate'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOptionButton(
                  title: 'Comment',
                  icon: Icons.comment,
                  onTap: () => _selectOption('comment'),
                ),
                ),
              ],
            ),
            
          const SizedBox(height: 24),
          
        _buildPostCard(),
      ],
    );
  }
  
  Widget _buildOptionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
                ),
                child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
                        Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
              textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    ),
    );
  }
            
  Widget _buildPostCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              "LinkedIn post detected",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 16,
                      child: Text(
                        _postAuthor.isNotEmpty ? _postAuthor[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _postAuthor,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _postDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Show image indicator if there are images
                if (_postImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildImagePreview(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview() {
    return Row(
      children: [
        Icon(
          Icons.photo,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          '${_postImages.length} image${_postImages.length > 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
  
  Widget _buildSummarizeContent() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
              Text(
                    'Post Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedOption = ''),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
              ),
            ],
              ),
              
              const SizedBox(height: 16),
              
          // Use the fancy dropdown field
          _buildDropdownField(
            label: 'Summary Type',
            hintText: 'Select the type of summary',
            controller: _summaryTypeController,
            icon: Icons.format_list_bulleted,
            options: ['Concise', 'Brief', 'Detailed'],
          ),
          
          const SizedBox(height: 16),
          
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _generateSummary(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                iconColor: Colors.white, // Explicitly set icon color
              ),
              icon: _isLoading ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ) : const Icon(Icons.summarize, color: Colors.white), // Explicitly set icon color
              label: Text(_isLoading ? 'Generating...' : 'Generate Summary'),
            ),
          ),
            
          const SizedBox(height: 24),
              
          _buildPostCard(),
            
          const SizedBox(height: 24),
            
          _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _summary.isNotEmpty
            ? Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        radius: 16,
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI-Generated Summary',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
                        ),
                      ),
                    ],
            ),
            
            const SizedBox(height: 16),
            
                Text(_summary),
                  
                  const SizedBox(height: 16),
                  
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _summary)).then((_) {
                            ToastUtils.showSuccessToast('Summary copied to clipboard');
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Summary'),
                      ),
              ],
            ),
              ),
            )
            : const SizedBox.shrink(),
      ],
    );
  }
  
  Widget _buildTranslateContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Translate Post',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                      ),
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedOption = ''),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
          ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Use the fancy dropdown field
        _buildDropdownField(
          label: 'Translation Language',
          hintText: 'Select the language to translate to',
          controller: _translationLanguageController,
          icon: Icons.language,
          options: _availableLanguages,
        ),
        
        const SizedBox(height: 16),
        
        // Generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading || _translationLanguageController.text == 'Default' ? null : () => _generateTranslation(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              iconColor: Colors.white, // Explicitly set icon color
            ),
            icon: _isLoading ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ) : const Icon(Icons.translate, color: Colors.white), // Explicitly set icon color
            label: Text(_isLoading ? 'Translating...' : 'Translate Post'),
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildPostCard(),
          
        const SizedBox(height: 24),
          
        _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _translation.isNotEmpty
            ? Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            radius: 16,
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Translation to ${_translationLanguageController.text}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ),
                  ],
                ),
                      
                      const SizedBox(height: 16),
                      
                      Text(_translation),
                      
                      const SizedBox(height: 16),
                      
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _translation)).then((_) {
                            ToastUtils.showSuccessToast('Translation copied to clipboard');
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Translation'),
            ),
        ],
      ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
  
  Widget _buildCommentContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                Icon(Icons.comment, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
        Text(
                  'Generate Comment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedOption = ''),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Use the fancy dropdown field
          _buildDropdownField(
            label: 'Comment Tone',
            hintText: 'Select the tone for your comment',
            controller: _commentToneController,
            icon: Icons.sentiment_satisfied_alt,
            options: _availableCommentTones,
          ),
          
          const SizedBox(height: 16),
          
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingComment ? null : () => _generateComment(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                iconColor: Colors.white, // Explicitly set icon color
              ),
              icon: _isGeneratingComment ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ) : const Icon(Icons.smart_toy, color: Colors.white), // Explicitly set icon color
              label: Text(_isGeneratingComment ? 'Generating...' : 'Generate Comment'),
            ),
          ),
          
          const SizedBox(height: 24),
          
        _buildPostCard(),
        
        const SizedBox(height: 24),
        
        // Only show generated comment if it's not empty
        if (_generatedComment.isNotEmpty) ...[
          Card(
            elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
              padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 16,
                        child: const Icon(
                          Icons.comment,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          'AI-Generated Comment',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                  
                  const SizedBox(height: 16),
                  
                  Text(_generatedComment),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedComment)).then((_) {
                            ToastUtils.showSuccessToast('Comment copied to clipboard');
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                      
                      TextButton.icon(
                        onPressed: _isGeneratingComment ? null : _generateComment,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate'),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Generate a comment based on the post and selected tone
  void _generateComment() {
    if (_postContent.isEmpty) {
      return;
    }
    
    setState(() {
      _isGeneratingComment = true;
    });
    
    // Simulate API call delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGeneratingComment = false;
        
        // Extract a short excerpt of the post content for the comment
        String excerpt = _postContent.length > 30 ? _postContent.substring(0, 30) + '...' : _postContent;
        
        // Generate different comments based on the selected tone
        switch (_commentToneController.text) {
          case 'Professional':
            _generatedComment = "Thank you for sharing these valuable insights. Your points about $excerpt are particularly relevant in today's context. I appreciate your perspective on this topic.";
            break;
          case 'Friendly':
            _generatedComment = "Love this post! The way you explained $excerpt really resonated with me. Thanks for sharing your thoughts on this!";
            break;
          case 'Enthusiastic':
            _generatedComment = "Wow! This is exactly what I needed to read today! Your insights on $excerpt are absolutely game-changing. Can't wait to see more content like this!";
            break;
          case 'Thoughtful':
            _generatedComment = "This post has given me a lot to reflect on. I've been considering the implications of $excerpt for some time, and your perspective adds a valuable dimension to the conversation.";
            break;
          case 'Questioning':
            _generatedComment = "Interesting perspective. I'm curious to know more about how you arrived at these conclusions about $excerpt? Have you considered alternative viewpoints on this topic?";
            break;
          case 'Supportive':
            _generatedComment = "I completely stand with you on this! Your points about $excerpt are spot-on and deserve more attention. Keep sharing these important insights!";
            break;
          default:
            _generatedComment = "Thank you for sharing this thoughtful post. It provides valuable insights on an important topic.";
        }
      });
      
      // Save to history with comment functionality
      _saveToHistoryWithComment();
      
      ToastUtils.showSuccessToast('Comment generated successfully');
    });
  }

  Widget _buildActionOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomDropdownField extends StatefulWidget {
  final String labelText;
  final TextEditingController controller;
  final VoidCallback onTap;

  const CustomDropdownField({
    super.key,
    required this.labelText,
    required this.controller,
    required this.onTap,
  });

  @override
  State<CustomDropdownField> createState() => _CustomDropdownFieldState();
}

class _CustomDropdownFieldState extends State<CustomDropdownField> {
  @override
  void initState() {
    super.initState();
    // Add listener to rebuild when controller value changes
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // Force widget to rebuild when controller value changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.labelText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.controller.text.isNotEmpty ? widget.controller.text : 'Select an option',
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.controller.text.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
} 