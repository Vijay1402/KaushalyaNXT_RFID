import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/providers/auth_provider.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends ConsumerState<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_AdminUserDialogResult>(
      context: context,
      builder: (context) => const _AdminUserDialog(),
    );

    final formData = result?.data;
    if (result == null ||
        result.action != _AdminUserDialogAction.save ||
        formData == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final createdUser = await ref.read(authServiceProvider).createUserAsAdmin(
            name: formData.name,
            email: formData.email,
            password: formData.password,
            role: formData.role,
            phone: formData.phone,
            farmManagerCode: formData.farmManagerCode,
          );

      if (!mounted) {
        return;
      }

      final message = createdUser.managerCode.isEmpty
          ? '${_roleLabel(createdUser.role)} account created successfully.'
          : '${_roleLabel(createdUser.role)} account created. Manager code: '
              '${createdUser.managerCode}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openEditDialog(_AdminUserRecord user) async {
    final result = await showDialog<_AdminUserDialogResult>(
      context: context,
      builder: (context) => _AdminUserDialog(user: user),
    );

    if (result == null) {
      return;
    }

    if (result.action == _AdminUserDialogAction.remove) {
      await _removeUser(user);
      return;
    }

    final formData = result.data;
    if (formData == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final updatedUser = await ref.read(authServiceProvider).updateUserAsAdmin(
            userId: user.id,
            name: formData.name,
            phone: formData.phone,
            farmManagerCode: formData.farmManagerCode,
          );

      if (!mounted) {
        return;
      }

      final message = updatedUser.farmManagerCode.isEmpty
          ? 'User profile updated successfully.'
          : 'User updated and linked to manager code '
              '${updatedUser.farmManagerCode}.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _removeUser(_AdminUserRecord user) async {
    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove User'),
            content: Text(
              'Remove ${user.name} from the app?\n\n'
              'This deletes the Firestore user profile and unlinks managed '
              'farmers if needed. It does not delete the Firebase Auth '
              'account because Admin SDK is not configured here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(authServiceProvider).removeUserAsAdmin(userId: user.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} was removed from app access.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text(
              'Do you want to sign out from the admin dashboard?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    context.go(RoutePaths.login);
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).user;
    final adminName =
        (currentUser?.name.trim().isNotEmpty ?? false) ? currentUser!.name : '';
    final currentUserId = ref.read(authServiceProvider).getCurrentUser()?.uid;
    final usersAsync = ref.watch(usersSnapshotsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F1),
      body: SafeArea(
        child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load users: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (snapshot) {
            final allUsers = snapshot.docs
                .map(_AdminUserRecord.fromDoc)
                .toList(growable: false);
            final filteredUsers = _filterUsers(allUsers);
            final counts = _AdminUserCounts.from(allUsers);

            return Column(
              children: [
                _AdminHeader(
                  adminName: adminName,
                  onActivityTap: () => context.push(RoutePaths.activityLog),
                  onProfileTap: () => context.push('/profile'),
                  onLogoutTap: _logout,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search users, email, phone, or manager code',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Total Users',
                              value: '${counts.total}',
                              icon: Icons.groups_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'Admins',
                              value: '${counts.admins}',
                              icon: Icons.admin_panel_settings_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Farm Managers',
                              value: '${counts.managers}',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'Farmers',
                              value: '${counts.farmers}',
                              icon: Icons.agriculture_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5E6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'This dashboard works without Firebase Admin SDK. '
                      'It can create accounts using a secondary client auth '
                      'session and update Firestore user profiles safely.',
                      style: TextStyle(
                        color: Color(0xFF27552B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _openCreateDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _isSubmitting ? 'Working...' : 'Add New User',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8933),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isSubmitting)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'User Directory',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D2B1F),
                                ),
                              ),
                            ),
                            Text(
                              '${filteredUsers.length} shown',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filteredUsers.isEmpty
                              ? Center(
                                  child: Text(
                                    allUsers.isEmpty
                                        ? 'No users found in Firestore yet.'
                                        : 'No users match the current search.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredUsers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final user = filteredUsers[index];
                                    final isCurrentUser =
                                        user.id == currentUserId;

                                    return _UserTile(
                                      user: user,
                                      isCurrentUser: isCurrentUser,
                                      onTap: isCurrentUser
                                          ? () => context.push('/profile')
                                          : () => _openEditDialog(user),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_AdminUserRecord> _filterUsers(List<_AdminUserRecord> users) {
    final filtered = users.where((user) {
      if (_search.isEmpty) {
        return true;
      }

      final values = <String>[
        user.name,
        user.email,
        user.phone,
        user.role,
        user.managerCode,
        user.farmManagerName,
        user.farmManagerCode,
      ];

      return values.any((value) => value.toLowerCase().contains(_search));
    }).toList();

    filtered.sort((left, right) {
      final roleCompare =
          _roleOrder(left.role).compareTo(_roleOrder(right.role));
      if (roleCompare != 0) {
        return roleCompare;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return filtered;
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.adminName,
    required this.onActivityTap,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  final String adminName;
  final VoidCallback onActivityTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final displayName = adminName.trim().isEmpty ? 'Admin' : adminName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF2E8933),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onActivityTap,
                icon: const Icon(Icons.history, color: Colors.white),
              ),
              IconButton(
                onPressed: onProfileTap,
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
              IconButton(
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE7F5E6),
                child: Text(
                  _initialsFor(displayName),
                  style: const TextStyle(
                    color: Color(0xFF2E8933),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Namaste',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage users, data visibility, and admin operations.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2E8933)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isCurrentUser,
    required this.onTap,
  });

  final _AdminUserRecord user;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBF6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrentUser
                ? const Color(0xFF59C154)
                : const Color(0xFFE1E9DD),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _roleColor(user.role).withValues(alpha: 0.14),
                  child: Text(
                    _initialsFor(user.name),
                    style: TextStyle(
                      color: _roleColor(user.role),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D2B1F),
                              ),
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F5E6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Color(0xFF2E8933),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (user.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.phone,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isCurrentUser
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoleChip(
                  label: _roleLabel(user.role),
                  color: _roleColor(user.role),
                ),
                if (user.managerCode.isNotEmpty)
                  _RoleChip(
                    label: 'Code ${user.managerCode}',
                    color: const Color(0xFF2E8933),
                  ),
                if (user.farmManagerName.isNotEmpty)
                  _RoleChip(
                    label: user.farmManagerCode.isEmpty
                        ? 'Linked to ${user.farmManagerName}'
                        : 'Linked to ${user.farmManagerName} '
                            '(${user.farmManagerCode})',
                    color: const Color(0xFF0E7490),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog({this.user});

  final _AdminUserRecord? user;

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _farmManagerCodeController;

  late String _role;
  bool _obscurePassword = true;

  bool get _isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _passwordController = TextEditingController();
    _farmManagerCodeController = TextEditingController(
      text: widget.user?.farmManagerCode ?? '',
    );
    _role = widget.user?.role ?? 'farmer';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _farmManagerCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit User' : 'Add New User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                readOnly: _isEditMode,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: _isEditMode
                      ? 'Auth email changes still need a server-side admin flow.'
                      : null,
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  final emailPattern =
                      RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (email.isEmpty) {
                    return 'Email is required';
                  }
                  if (!emailPattern.hasMatch(email)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                ),
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) {
                    return 'Phone is required';
                  }
                  if (digits.length < 10) {
                    return 'Enter at least 10 digits';
                  }
                  return null;
                },
              ),
              if (!_isEditMode) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'farm_manager',
                    child: Text('Farm Manager'),
                  ),
                  DropdownMenuItem(
                    value: 'farmer',
                    child: Text('Farmer'),
                  ),
                ],
                onChanged: _isEditMode
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _role = value;
                          if (_role != 'farmer') {
                            _farmManagerCodeController.clear();
                          }
                        });
                      },
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Role is locked here to avoid breaking existing account links.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_role == 'farmer') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _farmManagerCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Farm Manager Code',
                    helperText:
                        'Optional. Leave empty to keep the farmer unlinked.',
                  ),
                ),
              ],
              if (_role == 'farm_manager' &&
                  (widget.user?.managerCode.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.user!.managerCode,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Manager Code',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditMode)
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                const _AdminUserDialogResult(
                  action: _AdminUserDialogAction.remove,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove User'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditMode ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _AdminUserDialogResult(
        action: _AdminUserDialogAction.save,
        data: _AdminUserFormData(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text.trim(),
          role: _role,
          farmManagerCode: _farmManagerCodeController.text.trim(),
        ),
      ),
    );
  }
}

class _AdminUserCounts {
  const _AdminUserCounts({
    required this.total,
    required this.admins,
    required this.managers,
    required this.farmers,
  });

  final int total;
  final int admins;
  final int managers;
  final int farmers;

  factory _AdminUserCounts.from(List<_AdminUserRecord> users) {
    var admins = 0;
    var managers = 0;
    var farmers = 0;

    for (final user in users) {
      switch (_normalizedRole(user.role)) {
        case 'admin':
          admins++;
        case 'farm_manager':
          managers++;
        default:
          farmers++;
      }
    }

    return _AdminUserCounts(
      total: users.length,
      admins: admins,
      managers: managers,
      farmers: farmers,
    );
  }
}

class _AdminUserRecord {
  const _AdminUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.managerCode,
    required this.farmManagerName,
    required this.farmManagerCode,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String managerCode;
  final String farmManagerName;
  final String farmManagerCode;

  factory _AdminUserRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _AdminUserRecord(
      id: doc.id,
      name: (data['name'] ?? 'User').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      phone: (data['phone'] ?? '').toString().trim(),
      role: (data['role'] ?? 'farmer').toString().trim(),
      managerCode: (data['managerCode'] ?? '').toString().trim(),
      farmManagerName: (data['farmManagerName'] ?? '').toString().trim(),
      farmManagerCode: (data['farmManagerCode'] ?? '').toString().trim(),
    );
  }
}

class _AdminUserFormData {
  const _AdminUserFormData({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.farmManagerCode,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  final String farmManagerCode;
}

enum _AdminUserDialogAction {
  save,
  remove,
}

class _AdminUserDialogResult {
  const _AdminUserDialogResult({
    required this.action,
    this.data,
  });

  final _AdminUserDialogAction action;
  final _AdminUserFormData? data;
}

int _roleOrder(String role) {
  switch (_normalizedRole(role)) {
    case 'admin':
      return 0;
    case 'farm_manager':
      return 1;
    default:
      return 2;
  }
}

Color _roleColor(String role) {
  switch (_normalizedRole(role)) {
    case 'admin':
      return const Color(0xFF1F6D2C);
    case 'farm_manager':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF0E7490);
  }
}

String _normalizedRole(String role) {
  return role.trim().toLowerCase();
}

String _roleLabel(String role) {
  switch (_normalizedRole(role)) {
    case 'admin':
      return 'Admin';
    case 'farm_manager':
      return 'Farm Manager';
    default:
      return 'Farmer';
  }
}

String _initialsFor(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'AD';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}
