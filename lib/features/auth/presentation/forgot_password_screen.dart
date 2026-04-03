import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool isLoading = false;

  /// 🔥 EMAIL VALIDATION
  bool isValidEmail(String email) {
    return RegExp(
            r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
        .hasMatch(email);
  }

  /// 🔥 FIREBASE RESET FUNCTION
  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage("Please enter email");
      return;
    }

    if (!isValidEmail(email)) {
      showMessage("Enter valid email");
      return;
    }

    try {
      setState(() => isLoading = true);

      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

      if (!mounted) return;

      showMessage("Reset link sent to your email");

      Navigator.pop(context); // 🔙 go back to login
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? "Something went wrong");
    } catch (e) {
      showMessage("Error occurred");
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              /// TITLE
              const Text(
                "Forget Password",
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              /// SUBTITLE
              const Text(
                "Enter your Email to receive a password reset link",
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 30),

              /// EMAIL FIELD
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Email Address",
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          "SEND RESET LINK",
                          style:
                              TextStyle(color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              /// BACK TO LOGIN
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration:
                          TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}