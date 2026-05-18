import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    this.showBackButton = true,
  });

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final userName =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : "Farmer";
    final userEmail =
        (user?.email.trim().isNotEmpty ?? false) ? user!.email.trim() : "-";
    final userRole =
        (user?.role.trim().isNotEmpty ?? false) ? user!.role.trim() : "farmer";
    final userPhone =
        (user?.phone.trim().isNotEmpty ?? false) ? user!.phone.trim() : "-";
    final managerCode = (user?.managerCode.trim().isNotEmpty ?? false)
        ? user!.managerCode.trim()
        : '';
    final farmManagerName = (user?.farmManagerName.trim().isNotEmpty ?? false)
        ? user!.farmManagerName.trim()
        : '';
    final farmManagerCode = (user?.farmManagerCode.trim().isNotEmpty ?? false)
        ? user!.farmManagerCode.trim()
        : '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(context.tr('profile')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: Text(context.tr('notificationSettings')),
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(context.tr('faqs')),
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(context.tr('support')),
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.tr('aboutApp')),
                ),
              ),
              PopupMenuItem(
                value: 5,
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(context.tr('language')),
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 1:
                  context.push('/notification-settings');
                  break;
                case 2:
                  context.push('/faq');
                  break;
                case 3:
                  context.push('/support');
                  break;
                case 4:
                  showAboutAppDialog(context);
                  break;
                case 5:
                  _showLanguageDialog(context, ref);
                  break;
              }
            },
          ),
        ],
      ),
      body: ResponsiveScrollBody(
        maxWidth: 920,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 16,
          bottom: 24,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showTwoColumns = constraints.maxWidth >= 760;
            final infoCard = _buildInfoCard(
              context,
              userRole,
              userEmail,
              userPhone,
              managerCode,
              farmManagerName,
              farmManagerCode,
            );
            final farmDetailsCard = _buildFarmDetails(context);

            return Column(
              children: [
                _buildProfileHeader(userName, userRole, managerCode),
                const SizedBox(height: 20),
                if (showTwoColumns)
                  ResponsiveWrapGrid(
                    minChildWidth: 320,
                    maxColumns: 2,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      infoCard,
                      farmDetailsCard,
                    ],
                  )
                else ...[
                  infoCard,
                  const SizedBox(height: 20),
                  farmDetailsCard,
                ],
                const SizedBox(height: 20),
                _buildActions(
                  context,
                  ref,
                  authState.isLoading,
                  userName,
                  userEmail,
                  userPhone,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selectedLocale = ref.read(appLanguageProvider);
    final selectedCode = selectedLocale.languageCode;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('chooseLanguage')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: supportedAppLanguages.map((language) {
              final isSelected = language.code == selectedCode;

              return ListTile(
                onTap: () async {
                  await ref
                      .read(appLanguageProvider.notifier)
                      .setLanguage(language.code);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.green.shade700 : null,
                ),
                title: Text(language.nativeName),
                subtitle: Text(language.name),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Colors.green.shade700)
                    : null,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileHeader(
    String userName,
    String userRole,
    String managerCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    _ProfileHeaderText(
                      userName: userName,
                      userRole: userRole,
                      managerCode: managerCode,
                      formatRoleLabel: _formatRoleLabel,
                    ),
                  ],
                )
              : Row(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.green),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ProfileHeaderText(
                        userName: userName,
                        userRole: userRole,
                        managerCode: managerCode,
                        formatRoleLabel: _formatRoleLabel,
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String userRole,
    String userEmail,
    String userPhone,
    String managerCode,
    String farmManagerName,
    String farmManagerCode,
  ) {
    return _card(
      title: context.tr('personalInformation'),
      children: [
        _InfoRow(
            icon: Icons.phone, label: context.tr('phone'), value: userPhone),
        _InfoRow(
          icon: Icons.location_on,
          label: context.tr('location'),
          value: 'Karnataka, India',
        ),
        _InfoRow(
            icon: Icons.email, label: context.tr('email'), value: userEmail),
        if (userRole.trim().toLowerCase() == 'farm_manager' &&
            managerCode.isNotEmpty)
          _InfoRow(
            icon: Icons.badge_outlined,
            label: context.tr('managerCode'),
            value: managerCode,
          ),
        if (userRole.trim().toLowerCase() == 'farmer')
          _InfoRow(
            icon: Icons.supervisor_account_outlined,
            label: context.tr('farmManager'),
            value: farmManagerName.isEmpty
                ? context.tr('notLinked')
                : (farmManagerCode.isEmpty
                    ? farmManagerName
                    : "$farmManagerName ($farmManagerCode)"),
          ),
      ],
    );
  }

  Widget _buildFarmDetails(BuildContext context) {
    return _card(
      title: context.tr('farmDetails'),
      children: [
        _InfoRow(
            icon: Icons.landscape,
            label: context.tr('landSize'),
            value: "5 Acres"),
        _InfoRow(
            icon: Icons.park, label: context.tr('totalTrees'), value: "120"),
        _InfoRow(
            icon: Icons.eco,
            label: context.tr('mainCrops'),
            value: "Mango, Coconut"),
        _InfoRow(
          icon: Icons.water_drop,
          label: context.tr('irrigation'),
          value: "Drip Irrigation",
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isLoading,
    String userName,
    String userEmail,
    String userPhone,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => _showEditProfileDialog(
                      context,
                      ref,
                      userName: userName,
                      userEmail: userEmail,
                      userPhone: userPhone,
                    ),
            icon: const Icon(Icons.edit),
            label: Text(context.tr('editProfile')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                isLoading ? null : () => _sendPasswordReset(context, ref),
            icon: const Icon(Icons.lock_reset),
            label: Text(context.tr('resetPassword')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: Text(context.tr('logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref, {
    required String userName,
    required String userEmail,
    required String userPhone,
  }) async {
    final nameController =
        TextEditingController(text: userName == "Farmer" ? "" : userName);
    final emailController =
        TextEditingController(text: userEmail == "-" ? "" : userEmail);
    final phoneController =
        TextEditingController(text: userPhone == "-" ? "" : userPhone);
    String? nameError;
    String? emailError;
    String? phoneError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Edit Profile"),
              content: SizedBox(
                width: ResponsiveLayout.dialogWidth(dialogContext),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditField(
                      controller: nameController,
                      label: "Name",
                      icon: Icons.person_outline,
                      errorText: nameError,
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      controller: phoneController,
                      label: "Phone Number",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: emailError,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    final email = emailController.text.trim();
                    final emailPattern =
                        RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');

                    setDialogState(() {
                      nameError = null;
                      phoneError = null;
                      emailError = null;
                    });

                    var isValid = true;
                    if (name.isEmpty) {
                      nameError = "Name is required";
                      isValid = false;
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                      phoneError = "Enter valid 10 digit number";
                      isValid = false;
                    }
                    if (email.isEmpty) {
                      emailError = "Email is required";
                      isValid = false;
                    } else if (!emailPattern.hasMatch(email)) {
                      emailError = "Enter valid email";
                      isValid = false;
                    }

                    setDialogState(() {});
                    if (!isValid) return;

                    try {
                      await ref.read(authStateProvider.notifier).updateProfile(
                            name: name,
                            email: email,
                            phone: phone,
                          );

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            email == userEmail
                                ? "Profile updated"
                                : "Profile updated. Verify the email change from your inbox.",
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendPasswordReset(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authStateProvider.notifier).sendPasswordReset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Password reset email sent. Check Inbox and Spam folder."),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text("Logout"),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout?\nYou will need to login again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);

              final notifier = ref.read(authStateProvider.notifier);
              await notifier.logout();

              if (!context.mounted) return;
              context.go('/login');
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatRoleLabel(String userRole) {
    final normalized = userRole.trim();
    if (normalized.isEmpty) return 'Farmer';

    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final labelWidget = Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        );
        final valueWidget = Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: compact ? TextAlign.left : TextAlign.right,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(child: labelWidget),
                      ],
                    ),
                    const SizedBox(height: 6),
                    valueWidget,
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: labelWidget),
                    const SizedBox(width: 12),
                    Flexible(child: valueWidget),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileHeaderText extends StatelessWidget {
  const _ProfileHeaderText({
    required this.userName,
    required this.userRole,
    required this.managerCode,
    required this.formatRoleLabel,
  });

  final String userName;
  final String userRole;
  final String managerCode;
  final String Function(String) formatRoleLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (managerCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  managerCode,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatRoleLabel(userRole),
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

void showAboutAppDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveLayout.dialogWidth(context, maxWidth: 420),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Agri App",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "1.0",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Helping farmers digitally",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        showLicensePage(
                          context: context,
                          applicationName: "Agri App",
                          applicationVersion: "1.0",
                        );
                      },
                      child: const Text("View licenses"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
