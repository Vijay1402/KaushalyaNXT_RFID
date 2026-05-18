import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/widgets/responsive_layout.dart';
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
    final cardPadding = ResponsiveLayout.adaptiveSpace(
      context,
      min: 14,
      max: 20,
    );
    final headingSize = ResponsiveLayout.fontSize(context, 22);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: ResponsiveScrollBody(
        maxWidth: 420,
        fillViewport: true,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 20,
          bottom: 24,
          compact: 18,
          regular: 24,
          wide: 28,
        ),
        child: Column(
          children: [
            SizedBox(height: ResponsiveLayout.adaptiveSpace(context, min: 12)),
            Text(
              context.tr('Create Account'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: headingSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Create an account with email and password.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            SizedBox(height: ResponsiveLayout.adaptiveSpace(context, min: 18)),
            Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Column(
                children: [
                  _inputField(nameController, context.tr('Full Name')),
                  const SizedBox(height: 15),
                  _inputField(
                    phoneController,
                    context.tr('Phone Number'),
                    keyboardType: TextInputType.phone,
                    errorText: phoneError,
                  ),
                  if (role == 'farmer') ...[
                    const SizedBox(height: 15),
                    _inputField(
                      farmManagerCodeController,
                      context.tr('Farm Manager Code (Optional)'),
                      errorText: farmManagerCodeError,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr(
                          'Add a farm manager code only if you want to work under that manager.',
                        ),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  _inputField(
                    emailController,
                    context.tr('Email Address'),
                    keyboardType: TextInputType.emailAddress,
                    errorText: emailError,
                  ),
                  const SizedBox(height: 15),
                  _inputField(
                    passwordController,
                    context.tr('Password'),
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
                    context.tr('Confirm Password'),
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
                      items: [
                        DropdownMenuItem(
                          value: 'farmer',
                          child: Text(context.tr('Farmer')),
                        ),
                        DropdownMenuItem(
                          value: 'farm_manager',
                          child: Text(context.tr('Farm Manager')),
                        ),
                        const DropdownMenuItem(
                          value: 'kvk',
                          child: Text('KVK'),
                        ),
                        const DropdownMenuItem(
                          value: 'agriculture_officer',
                          child: Text('Agriculture Officer'),
                        ),
                        const DropdownMenuItem(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr(
                          'Your farm manager code will be generated automatically after registration.',
                        ),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: ResponsiveLayout.adaptiveSpace(context, min: 18)),
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
                      child: Text(
                        context.tr('SIGN UP'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
            SizedBox(height: ResponsiveLayout.adaptiveSpace(context, min: 16)),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(context.tr('Already have an account? ')),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    context.tr('LOGIN'),
                    style: const TextStyle(
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
