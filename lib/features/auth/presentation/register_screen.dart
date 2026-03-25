import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// 🔝 TOP BAR
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /// LOGO
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.eco,
                          color: Colors.white, size: 18),
                    ),

                    /// ICONS
                    Row(
                      children: const [
                        Icon(Icons.notifications_none),
                        SizedBox(width: 12),
                        Icon(Icons.person_outline),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// TITLE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text(
                    "Create an Account",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              /// FULL NAME
              _inputField(nameController, "Full Name"),

              const SizedBox(height: 15),

              /// EMAIL
              _inputField(emailController, "Email Address"),

              const SizedBox(height: 15),

              /// PASSWORD
              _inputField(
                passwordController,
                "Password",
                isPassword: true,
                obscure: obscurePassword,
                onToggle: () =>
                    setState(() => obscurePassword = !obscurePassword),
              ),

              const SizedBox(height: 15),

              /// CONFIRM PASSWORD
              _inputField(
                confirmPasswordController,
                "Confirm Password",
                isPassword: true,
                obscure: obscureConfirmPassword,
                onToggle: () => setState(
                    () => obscureConfirmPassword = !obscureConfirmPassword),
              ),

              const SizedBox(height: 25),

              /// SIGN UP BUTTON
              authState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
                          if (passwordController.text !=
                              confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Passwords do not match"),
                              ),
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .register(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  password:
                                      passwordController.text.trim(),
                                  role: "farmer",
                                );

                            if (!context.mounted) return;
                            context.go('/login');
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        child: const Text("SIGN UP"),
                      ),
                    ),

              const SizedBox(height: 15),

              /// TERMS
              const Text(
                "By signing up, you agree to our Terms of Service and Privacy Policy",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),

              const SizedBox(height: 30),

              /// LOGIN LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      "LOGIN",
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

  /// 🔧 INPUT FIELD
  Widget _inputField(
    TextEditingController controller,
    String hint, {
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon:
              isPassword ? const Icon(Icons.lock_outline) : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }
}