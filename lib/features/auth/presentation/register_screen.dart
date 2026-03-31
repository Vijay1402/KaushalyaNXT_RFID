import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends ConsumerState<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;

  String role = "farmer";

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// HEADER
              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 25),

              /// CARD CONTAINER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6)
                  ],
                ),
                child: Column(
                  children: [
                    /// NAME
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
                      onToggle: () => setState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// CONFIRM PASSWORD
                    _inputField(
                      confirmPasswordController,
                      "Confirm Password",
                      isPassword: true,
                      obscure: obscureConfirm,
                      onToggle: () => setState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// ROLE DROPDOWN
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: role,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                              value: "farmer",
                              child: Text("Farmer")),
                          DropdownMenuItem(
                              value: "kvk",
                              child: Text("KVK")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            role = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// REGISTER BUTTON
              authState.isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
                          final messenger =
                              ScaffoldMessenger.of(context);

                          /// VALIDATION
                          if (nameController.text.isEmpty ||
                              emailController.text.isEmpty ||
                              passwordController.text.isEmpty ||
                              confirmPasswordController
                                  .text.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Fill all fields")),
                            );
                            return;
                          }

                          if (passwordController.text !=
                              confirmPasswordController.text) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Passwords do not match")),
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .register(
                                  name: nameController.text.trim(),
                                  email:
                                      emailController.text.trim(),
                                  password:
                                      passwordController.text.trim(),
                                  role: role,
                                );

                            if (!mounted) return;

                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Registered Successfully")),
                            );

                            context.go('/login');
                          } catch (e) {
                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(e.toString())),
                            );
                          }
                        },
                        child: const Text(
                          "SIGN UP",
                          style:
                              TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              /// LOGIN NAV
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

  /// INPUT FIELD (same UI)
  Widget _inputField(
    TextEditingController controller,
    String hint, {
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon:
            isPassword ? const Icon(Icons.lock_outline) : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggle,
              )
            : null,
      ),
    );
  }
}