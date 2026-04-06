import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      /// 🔥 APP BAR
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("FAQs"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      /// BODY
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: const [
            _FAQTile(
              question: "How to scan a tree?",
              answer:
                  "Go to the dashboard and tap on 'Scan Now'. Use the camera to scan the RFID tag attached to the tree.",
            ),
            SizedBox(height: 10),
            _FAQTile(
              question: "How to view reports?",
              answer:
                  "Navigate to the Reports tab from the bottom menu to see all your tree reports and analytics.",
            ),
            SizedBox(height: 10),
            _FAQTile(
              question: "How to update profile?",
              answer:
                  "Go to Profile screen and click on 'Edit Profile' to update your details.",
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔥 CUSTOM EXPANDABLE TILE (ACCORDION)
class _FAQTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),

        /// Arrow icon (matches your design)
        trailing: const Icon(Icons.keyboard_arrow_down),

        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}