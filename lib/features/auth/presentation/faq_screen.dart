import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../shared/widgets/responsive_layout.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.tr('faqs')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveScrollBody(
        maxWidth: 720,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 20,
          bottom: 24,
          compact: 16,
          regular: 18,
          wide: 24,
        ),
        child: Column(
          children: [
            _FAQTile(
              question: context.tr('How to scan a tree?'),
              answer: context.tr(
                "Go to the dashboard and tap on 'Scan Now'. Use the camera to scan the RFID tag attached to the tree.",
              ),
            ),
            const SizedBox(height: 10),
            _FAQTile(
              question: context.tr('How to view reports?'),
              answer: context.tr(
                'Navigate to the Reports tab from the bottom menu to see all your tree reports and analytics.',
              ),
            ),
            const SizedBox(height: 10),
            _FAQTile(
              question: context.tr('How to update profile?'),
              answer: context.tr(
                "Go to Profile screen and click on 'Edit Profile' to update your details.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQTile extends StatelessWidget {
  const _FAQTile({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          question,
          style: TextStyle(
            fontSize: ResponsiveLayout.fontSize(context, 16),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_down),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: ResponsiveLayout.fontSize(context, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
