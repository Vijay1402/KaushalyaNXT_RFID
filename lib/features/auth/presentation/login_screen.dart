import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/router/route_paths.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;

  String? emailError;
  String? passwordError;

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              /// TITLE
              const Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 30),

              /// EMAIL
              _inputField(
                controller: emailController,
                hint: "Email Address",
                errorText: emailError,
              ),

              const SizedBox(height: 15),

              /// PASSWORD
              _inputField(
                controller: passwordController,
                hint: "Password",
                isPassword: true,
                obscure: obscurePassword,
                onToggle: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
                errorText: passwordError,
              ),

              /// FORGOT PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    context.push('/forgot-password');
                  },
                  child: const Text(
                    "Forget password?",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              /// LOGIN BUTTON
              authState.isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final router = GoRouter.of(context);

                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();

                          /// RESET ERRORS
                          setState(() {
                            emailError = null;
                            passwordError = null;
                          });

                          bool isValid = true;

                          /// EMAIL VALIDATION
                          if (email.isEmpty) {
                            emailError = "Email is required";
                            isValid = false;
                          } else if (!isValidEmail(email)) {
                            emailError = "Enter valid email";
                            isValid = false;
                          }

                          /// PASSWORD VALIDATION
                          if (password.isEmpty) {
                            passwordError = "Password is required";
                            isValid = false;
                          } else if (password.length < 6) {
                            passwordError = "Minimum 6 characters required";
                            isValid = false;
                          }

                          setState(() {});

                          if (!isValid) return;

                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .login(email, password);
                            if (!mounted) return;

                            final user = ref.read(authStateProvider).user;

                            if (user != null) {
                              router.go(RoutePaths.homeForRole(user.role));
                            }
                          } on FirebaseAuthException catch (e) {
                            /// 🔴 CLEAN ERROR MESSAGES
                            String message = "Login failed";

                            switch (e.code) {
                              case 'user-not-found':
                                message = "No user found with this email";
                                break;
                              case 'wrong-password':
                                message = "Incorrect password";
                                break;
                              case 'invalid-email':
                                message = "Invalid email format";
                                break;
                              case 'invalid-credential':
                                message = "Invalid email or password";
                                break;
                              default:
                                message = e.message ?? "Login failed";
                            }

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            String message = "Invalid email or password";

                            final error = e.toString().toLowerCase();

                            if (error.contains('user-not-found')) {
                              message = "No user found with this email";
                            } else if (error.contains('wrong-password')) {
                              message = "Incorrect password";
                            } else if (error.contains('invalid-email')) {
                              message = "Invalid email format";
                            } else if (error.contains('invalid-credential')) {
                              message = "Invalid email or password";
                            }

                            messenger.showSnackBar(
                              // ✅ SAFE
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "LOG IN",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              /// DIVIDER
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[400])),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("OR"),
                  ),
                  Expanded(child: Divider(color: Colors.grey[400])),
                ],
              ),

              const SizedBox(height: 20),

              /// REGISTER NAV
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text(
                      "SIGN UP",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// INPUT FIELD
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                blurRadius: 4,
                color: Colors.black12,
              )
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              prefixIcon: isPassword ? const Icon(Icons.lock_outline) : null,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: onToggle,
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 5),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
