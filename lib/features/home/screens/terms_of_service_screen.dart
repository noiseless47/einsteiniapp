import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/terms_of_service.dart';
import '../../../core/widgets/custom_app_bar.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: TermsOfService.title,
        showBackButton: true,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TermsOfService.lastUpdated,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Markdown(
                  data: TermsOfService.content,
                  styleSheet: MarkdownStyleSheet(
                    h1: theme.textTheme.headlineMedium!,
                    h2: theme.textTheme.titleLarge!,
                    h3: theme.textTheme.titleMedium!,
                    p: theme.textTheme.bodyMedium!,
                    listBullet: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href));
                    }
                  },
                  shrinkWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 