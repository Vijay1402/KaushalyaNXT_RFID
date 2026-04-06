import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController issueController = TextEditingController();

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
        title: const Text("Support"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      /// BODY
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE
            const Center(
              child: Text(
                "Need Help? Contact Us",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// TEXT FIELD
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: issueController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "Describe your issue...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final text = issueController.text.trim();

                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please describe your issue"),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Submitted successfully"),
                    ),
                  );

                  issueController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  "Submit",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// DIVIDER
            Divider(color: Colors.grey.shade400),

            const SizedBox(height: 20),

            /// EMAIL
            Row(
              children: const [
                Icon(Icons.email, color: Colors.black54),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Email",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "support@agriapp.com",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// PHONE
            Row(
              children: const [
                Icon(Icons.phone, color: Colors.black54),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Phone",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "+91 9876543210",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}