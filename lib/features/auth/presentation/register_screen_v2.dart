import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final farmManagerCodeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;

  String role = "farmer";
  String? phoneError;
  String? farmManagerCodeError;
  String? emailError;
  String? passwordError;
  String? confirmError;

  bool isValidEmail(String email) {
    return RegExp(r"^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$").hasMatch(email);
  }

  String _messageFromError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();

    if (lower.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (lower.contains('weak-password')) {
      return 'Choose a stronger password.';
    }
    return message;
  }

  Future<void> _register() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final phone = phoneController.text.trim();
    final farmManagerCode = farmManagerCodeController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    setState(() {
      phoneError = null;
      farmManagerCodeError = null;
      emailError = null;
      passwordError = null;
      confirmError = null;
    });

    var isValid = true;
    if (nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Full name is required')),
      );
      isValid = false;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      phoneError = 'Enter valid 10 digit number';
      isValid = false;
    }
    if (role == 'farmer' &&
        farmManagerCode.isNotEmpty &&
        farmManagerCode.length < 6) {
      farmManagerCodeError = 'Enter a valid farm manager code';
      isValid = false;
    }
    if (email.isEmpty) {
      emailError = 'Email is required';
      isValid = false;
    } else if (!isValidEmail(email)) {
      emailError = 'Enter valid email';
      isValid = false;
    }
    if (password.length < 6) {
      passwordError = 'Minimum 6 characters required';
      isValid = false;
    }
    if (password != confirm) {
      confirmError = 'Passwords do not match';
      isValid = false;
    }

    setState(() {});
    if (!isValid) return;

    try {
      await ref.read(authStateProvider.notifier).register(
            name: nameController.text.trim(),
            email: email,
            password: password,
            role: role,
            phone: phone,
            farmManagerCode: role == 'farmer' ? farmManagerCode : '',
          );
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Registered Successfully')),
      );
      router.go(RoutePaths.homeForRole(role));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_messageFromError(e))),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    farmManagerCodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account with email and password.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 25),
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
                    _inputField(nameController, 'Full Name'),
                    const SizedBox(height: 15),
                    _inputField(
                      phoneController,
                      'Phone Number',
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                    ),
                    if (role == 'farmer') ...[
                      const SizedBox(height: 15),
                      _inputField(
                        farmManagerCodeController,
                        'Farm Manager Code (Optional)',
                        errorText: farmManagerCodeError,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add a farm manager code only if you want to work under that manager.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    _inputField(
                      emailController,
                      'Email Address',
                      keyboardType: TextInputType.emailAddress,
                      errorText: emailError,
                    ),
                    const SizedBox(height: 15),
                    _inputField(
                      passwordController,
                      'Password',
                      isPassword: true,
                      obscure: obscurePassword,
                      onToggle: () => setState(
                        () => obscurePassword = !obscurePassword,
                      ),
                      errorText: passwordError,
                    ),
                    const SizedBox(height: 15),
                    _inputField(
                      confirmPasswordController,
                      'Confirm Password',
                      isPassword: true,
                      obscure: obscureConfirm,
                      onToggle: () => setState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                      errorText: confirmError,
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: role,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'farmer',
                            child: Text('Farmer'),
                          ),
                          DropdownMenuItem(
                            value: 'farm_manager',
                            child: Text('Farm Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'kvk',
                            child: Text('KVK'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            role = value!;
                            farmManagerCodeError = null;
                            if (role != 'farmer') {
                              farmManagerCodeController.clear();
                            }
                          });
                        },
                      ),
                    ),
                    if (role == 'farm_manager') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your farm manager code will be generated automatically after registration.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 25),
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
                        onPressed: _register,
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'LOGIN',
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

  Widget _inputField(
    TextEditingController controller,
    String hint, {
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? errorText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: isPassword ? const Icon(Icons.lock_outline) : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
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
