import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool isLoading = false;

  /// 🔥 EMAIL VALIDATION
  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  /// 🔥 FIREBASE RESET FUNCTION
  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(context.tr('Please enter email'));
      return;
    }

    if (!isValidEmail(email)) {
      showMessage(context.tr('Enter valid email'));
      return;
    }

    try {
      setState(() => isLoading = true);

      await ref.read(authServiceProvider).sendPasswordResetEmail(email);

      if (!mounted) return;

      showMessage(context.tr('Reset link sent to your email'));

      Navigator.pop(context); // 🔙 go back to login
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? context.tr('Something went wrong'));
    } catch (e) {
      showMessage(context.tr('Error occurred'));
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 🔥 SNACKBAR
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = ResponsiveLayout.fontSize(context, 24);
    final verticalGap = ResponsiveLayout.adaptiveSpace(
      context,
      min: 16,
      max: 32,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: ResponsiveScrollBody(
        maxWidth: 480,
        fillViewport: true,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 24,
          bottom: 24,
          compact: 18,
          regular: 24,
          wide: 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: verticalGap),
            Text(
              context.tr('Forget Password'),
              style: TextStyle(
                color: const Color(0xFF2E7D32),
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: verticalGap * 0.6),
            Text(
              context.tr('Enter your Email to receive a password reset link'),
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            SizedBox(height: verticalGap),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.tr('Email Address'),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: verticalGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : resetPassword,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.tr('SEND RESET LINK')),
              ),
            ),
            SizedBox(height: verticalGap * 0.75),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  context.tr('Back to Login'),
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
