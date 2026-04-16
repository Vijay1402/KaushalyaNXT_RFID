import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return RegExp(r"^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$").hasMatch(email);
  }

  String _messageFromError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();

    if (lower.contains('user-not-found')) {
      return 'No user found with this email';
    }
    if (lower.contains('wrong-password')) return 'Incorrect password';
    if (lower.contains('invalid-email')) return 'Invalid email format';
    if (lower.contains('invalid-credential')) return 'Invalid credentials';
    if (lower.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    return message;
  }

  Future<void> _loginWithEmail() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      emailError = null;
      passwordError = null;
    });

    var isValid = true;
    if (email.isEmpty) {
      emailError = 'Email is required';
      isValid = false;
    } else if (!isValidEmail(email)) {
      emailError = 'Enter valid email';
      isValid = false;
    }

    if (password.isEmpty) {
      passwordError = 'Password is required';
      isValid = false;
    } else if (password.length < 6) {
      passwordError = 'Minimum 6 characters required';
      isValid = false;
    }

    setState(() {});
    if (!isValid) return;

    try {
      await ref.read(authStateProvider.notifier).login(email, password);
      if (!mounted) return;

      final user = ref.read(authStateProvider).user;
      if (user != null) {
        router.go(RoutePaths.homeForRole(user.role));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_messageFromError(e))),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your registered email address.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  children: [
                    _inputField(
                      controller: emailController,
                      hint: 'Email Address',
                      errorText: emailError,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    _inputField(
                      controller: passwordController,
                      hint: 'Password',
                      isPassword: true,
                      obscure: obscurePassword,
                      onToggle: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                      errorText: passwordError,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text(
                          'Forget password?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                        onPressed: _loginWithEmail,
                        child: const Text(
                          'LOG IN',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[400])),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider(color: Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text(
                      'SIGN UP',
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

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? errorText,
    TextInputType? keyboardType,
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
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
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
