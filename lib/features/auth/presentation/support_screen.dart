import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/auth_provider.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final TextEditingController issueController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    issueController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportIssue() async {
    final text = issueController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr('Please describe your issue')),
        ),
      );
      return;
    }

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to submit support.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appUser = ref.read(authStateProvider).user;
      final firestore = ref.read(firestoreProvider);
      final reportRef = firestore.collection('issues').doc();

      final farmerName = _firstNonEmptyString([
        appUser?.name,
        user.displayName,
        user.email,
      ]);
      final farmerEmail = _firstNonEmptyString([
        appUser?.email,
        user.email,
      ]);
      final managerId = _firstNonEmptyString([
        appUser?.farmManagerId,
      ]);
      final managerCode = _firstNonEmptyString([
        appUser?.farmManagerCode,
      ]);

      final issueData = {
        'reportId': reportRef.id,
        'treeDocId': '',
        'treeId': 'Support',
        'species': 'Support',
        'healthStatus': 'Support',
        'title': text,
        'farm': 'Support',
        'ownerName': farmerName,
        'farmerName': farmerName,
        'userId': user.uid,
        'farmerId': user.uid,
        'userEmail': farmerEmail,
        'farmerEmail': farmerEmail,
        'managerId': managerId,
        'farmManagerId': managerId,
        'managerCode': managerCode,
        'farmManagerCode': managerCode,
        'farmManagerName': appUser?.farmManagerName ?? '',
        'note': text,
        'localImagePath': '',
        'hasImage': false,
        'imageUrl': '',
        'status': 'open',
        'source': 'support',
        'reportedByUid': user.uid,
        'reportedByEmail': farmerEmail,
        'createdAtLocal': DateTime.now().toIso8601String(),
      };
      final topLevelIssueData = {
        ...issueData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = firestore.batch();
      batch.set(reportRef, topLevelIssueData, SetOptions(merge: true));
      batch.set(
          firestore.collection('users').doc(user.uid),
          {
            'latestSupportIssue': issueData,
            'latestSupportIssueStatus': 'open',
            'latestSupportIssueMessage': text,
            'latestSupportIssueAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      await batch.commit();

      if (!mounted) return;
      issueController.clear();
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Submitted successfully'))),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to submit support issue.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionGap = ResponsiveLayout.adaptiveSpace(
      context,
      min: 16,
      max: 28,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.tr('support')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveScrollBody(
        maxWidth: 620,
        fillViewport: true,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 20,
          bottom: 24,
          compact: 16,
          regular: 20,
          wide: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Need Help? Contact Us'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveLayout.fontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: sectionGap),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Describe your issue'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: issueController,
                    maxLines: 5,
                    minLines: 4,
                    decoration: InputDecoration(
                      hintText: context.tr('Describe your issue...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitSupportIssue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.deepPurple,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _isSubmitting ? 'Submitting...' : context.tr('Submit'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            Divider(color: Colors.grey.shade400),
            SizedBox(height: sectionGap),
            ResponsiveWrapGrid(
              minChildWidth: 220,
              maxColumns: 2,
              spacing: 12,
              runSpacing: 12,
              children: [
                _SupportCard(
                  icon: Icons.email,
                  title: context.tr('email'),
                  value: 'support@agriapp.com',
                ),
                _SupportCard(
                  icon: Icons.phone,
                  title: context.tr('phone'),
                  value: '+91 9876543210',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
