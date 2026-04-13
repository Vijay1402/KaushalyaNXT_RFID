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

  /// 🔴 ERROR VARIABLES
  String? emailError;
  String? passwordError;
  String? confirmError;

  bool isValidEmail(String email) {
    return RegExp(
            r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
        .hasMatch(email);
  }

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

              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 25),

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
                    _inputField(nameController, "Full Name"),

                    const SizedBox(height: 15),

                    /// EMAIL
                    _inputField(
                      emailController,
                      "Email Address",
                      errorText: emailError,
                    ),

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
                      errorText: passwordError,
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
                      errorText: confirmError,
                    ),

                    const SizedBox(height: 15),

                    /// ROLE
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

              /// BUTTON
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
                          final router = GoRouter.of(context);

                          final email =
                              emailController.text.trim();
                          final password =
                              passwordController.text.trim();
                          final confirm =
                              confirmPasswordController.text.trim();

                          /// RESET ERRORS
                          setState(() {
                            emailError = null;
                            passwordError = null;
                            confirmError = null;
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
                          if (password.length < 6) {
                            passwordError =
                                "Minimum 6 characters required";
                            isValid = false;
                          }

                          /// CONFIRM PASSWORD
                          if (password != confirm) {
                            confirmError =
                                "Passwords do not match";
                            isValid = false;
                          }

                          setState(() {});

                          if (!isValid) return;

                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .register(
                                  name: nameController.text.trim(),
                                  email: email,
                                  password: password,
                                  role: role,
                                );

                            if (!mounted) return;

                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Registered Successfully")),
                            );

                            router.go('/login');
                          } catch (e) {
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

  /// INPUT FIELD WITH ERROR
  Widget _inputField(
    TextEditingController controller,
    String hint, {
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
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
                    icon: Icon(obscure
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: onToggle,
                  )
                : null,
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