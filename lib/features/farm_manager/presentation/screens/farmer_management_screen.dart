import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/responsive_layout.dart';
import '../farm_manager_data.dart';
import '../farm_manager_providers.dart';

class FarmerManagementScreen extends ConsumerStatefulWidget {
  const FarmerManagementScreen({
    super.key,
    this.initialFarmerId = '',
    this.initialFarmerName = '',
    this.initialFarmId = '',
    this.initialFarmLabel = '',
  });

  final String initialFarmerId;
  final String initialFarmerName;
  final String initialFarmId;
  final String initialFarmLabel;

  @override
  ConsumerState<FarmerManagementScreen> createState() =>
      _FarmerManagementScreenState();
}

class _FarmerManagementScreenState
    extends ConsumerState<FarmerManagementScreen> {
  String _searchText = '';

  Future<void> _copyValue(String label, String value) async {
    if (value.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _launchExternal(Uri uri, String failureMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _callFarmer(String phone) async {
    final value = phone.trim();
    if (value.isEmpty) {
      return;
    }
    await _launchExternal(
      Uri(scheme: 'tel', path: value),
      'Unable to open the dialer for this farmer.',
    );
  }

  Future<void> _emailFarmer(String email) async {
    final value = email.trim();
    if (value.isEmpty) {
      return;
    }
    await _launchExternal(
      Uri(scheme: 'mailto', path: value),
      'Unable to open email for this farmer.',
    );
  }

  void _showFarmerDetails(FarmManagerManagedFarmer farmer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final horizontalPadding = ResponsiveLayout.pagePadding(sheetContext);
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFDFF1E0),
                        child: Text(
                          initialsFor(farmer.name),
                          style: const TextStyle(
                            color: Color(0xFF2E8933),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farmer.name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#${farmer.farmerId}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FarmerStatPill(
                        icon: Icons.agriculture_outlined,
                        label: '${farmer.farmCount} farm(s)',
                        color: Colors.green.shade700,
                      ),
                      _FarmerStatPill(
                        icon: Icons.park_outlined,
                        label: '${farmer.totalTrees} tree(s)',
                        color: Colors.teal.shade700,
                      ),
                      _FarmerStatPill(
                        icon: Icons.warning_amber_rounded,
                        label: '${farmer.alertTreeCount} alert tree(s)',
                        color: farmer.alertTreeCount == 0
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView(
                      children: [
                        _FarmerDetailRow(
                          label: 'Role',
                          value: _roleLabel(farmer.role),
                        ),
                        _FarmerDetailRow(
                          label: 'Phone',
                          value: farmer.phone.isEmpty
                              ? 'Not available'
                              : farmer.phone,
                        ),
                        _FarmerDetailRow(
                          label: 'Email',
                          value: farmer.email.isEmpty
                              ? 'Not available'
                              : farmer.email,
                        ),
                        _FarmerDetailRow(
                          label: 'Linked To',
                          value: _managerLinkLabel(farmer),
                        ),
                        _FarmerDetailRow(
                          label: 'Health Score',
                          value: '${farmer.healthPercent}%',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Assigned Farms',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (farmer.assignedFarms.isEmpty)
                          Text(
                            'No farm links were derived from Firebase yet.',
                            style: TextStyle(color: Colors.grey.shade700),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: farmer.assignedFarms
                                .map(
                                  (farmLabel) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6EF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      farmLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E6E34),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ResponsiveWrapGrid(
                    minChildWidth: 120,
                    maxColumns: 3,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: farmer.phone.isEmpty
                            ? null
                            : () => _callFarmer(farmer.phone),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call'),
                      ),
                      OutlinedButton.icon(
                        onPressed: farmer.email.isEmpty
                            ? null
                            : () => _emailFarmer(farmer.email),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Email'),
                      ),
                      OutlinedButton.icon(
                        onPressed: farmer.hasContact
                            ? () => _copyValue(
                                  'Farmer contact',
                                  farmer.phone.isNotEmpty
                                      ? farmer.phone
                                      : farmer.email,
                                )
                            : null,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy'),
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

  @override
  Widget build(BuildContext context) {
    final managedFarmersAsync = ref.watch(managedFarmersProvider);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E8933),
        foregroundColor: Colors.white,
        title: const Text('Farmer Management'),
      ),
      body: managedFarmersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load connected farmers: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allFarmers) {
          final visibleFarmers = _filteredFarmers(allFarmers);
          final totalAssignedFarms = allFarmers.fold<int>(
            0,
            (sum, farmer) => sum + farmer.farmCount,
          );
          final totalTrees = allFarmers.fold<int>(
            0,
            (sum, farmer) => sum + farmer.totalTrees,
          );

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  12,
                ),
                padding: const EdgeInsets.all(18),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connected Farmers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203423),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.initialFarmLabel.trim().isEmpty
                          ? 'Firebase-linked farmer profiles managed by this farm manager.'
                          : 'Opened from ${widget.initialFarmLabel.trim()}. The linked farmer is highlighted below.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResponsiveWrapGrid(
                      minChildWidth: 110,
                      maxColumns: 3,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TopStatCard(
                          title: 'Farmers',
                          value: '${allFarmers.length}',
                          icon: Icons.people_alt_outlined,
                        ),
                        _TopStatCard(
                          title: 'Assigned Farms',
                          value: '$totalAssignedFarms',
                          icon: Icons.agriculture_outlined,
                        ),
                        _TopStatCard(
                          title: 'Trees',
                          value: '$totalTrees',
                          icon: Icons.park_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search farmers, phone, email, or farms',
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
              const SizedBox(height: 12),
              Expanded(
                child: visibleFarmers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            allFarmers.isEmpty
                                ? 'No connected farmers were found for this manager yet.'
                                : 'No farmers match the current search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        )
                      : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          24,
                        ),
                        itemCount: visibleFarmers.length,
                        itemBuilder: (context, index) {
                          final farmer = visibleFarmers[index];
                          final selected = _isInitiallySelected(farmer);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FarmerManagementCard(
                              farmer: farmer,
                              selected: selected,
                              onCallTap: farmer.phone.isEmpty
                                  ? null
                                  : () => _callFarmer(farmer.phone),
                              onEmailTap: farmer.email.isEmpty
                                  ? null
                                  : () => _emailFarmer(farmer.email),
                              onDetailsTap: () => _showFarmerDetails(farmer),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<FarmManagerManagedFarmer> _filteredFarmers(
    List<FarmManagerManagedFarmer> farmers,
  ) {
    final filtered = farmers.where((farmer) {
      if (_searchText.isEmpty) {
        return true;
      }

      final values = <String>[
        farmer.name,
        farmer.farmerId,
        farmer.email,
        farmer.phone,
        farmer.role,
        ...farmer.assignedFarms,
      ];

      return values.any(
        (value) => value.toLowerCase().contains(_searchText),
      );
    }).toList();

    filtered.sort((left, right) {
      final leftSelected = _isInitiallySelected(left);
      final rightSelected = _isInitiallySelected(right);
      if (leftSelected != rightSelected) {
        return leftSelected ? -1 : 1;
      }
      final leftFarmMatch = _matchesInitialFarm(left);
      final rightFarmMatch = _matchesInitialFarm(right);
      if (leftFarmMatch != rightFarmMatch) {
        return leftFarmMatch ? -1 : 1;
      }
      final treeCompare = right.totalTrees.compareTo(left.totalTrees);
      if (treeCompare != 0) {
        return treeCompare;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return filtered;
  }

  bool _isInitiallySelected(FarmManagerManagedFarmer farmer) {
    final initialFarmerId = widget.initialFarmerId.trim();
    if (initialFarmerId.isNotEmpty &&
        (farmer.id.trim() == initialFarmerId ||
            farmer.farmerId.trim() == initialFarmerId)) {
      return true;
    }

    final initialFarmerName = widget.initialFarmerName.trim().toLowerCase();
    return initialFarmerName.isNotEmpty &&
        farmer.name.trim().toLowerCase() == initialFarmerName;
  }

  bool _matchesInitialFarm(FarmManagerManagedFarmer farmer) {
    final initialFarmLabel = widget.initialFarmLabel.trim().toLowerCase();
    if (initialFarmLabel.isEmpty) {
      return false;
    }
    return farmer.assignedFarms.any(
      (farmLabel) => farmLabel.trim().toLowerCase() == initialFarmLabel,
    );
  }
}

class _FarmerManagementCard extends StatelessWidget {
  const _FarmerManagementCard({
    required this.farmer,
    required this.selected,
    required this.onCallTap,
    required this.onEmailTap,
    required this.onDetailsTap,
  });

  final FarmManagerManagedFarmer farmer;
  final bool selected;
  final VoidCallback? onCallTap;
  final VoidCallback? onEmailTap;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDetailsTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF59C154) : const Color(0xFFE3E9E1),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  selected ? const Color(0x1A59C154) : const Color(0x10000000),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFDFF1E0),
                  child: Text(
                    initialsFor(farmer.name),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              farmer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (selected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5EA),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Selected',
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
                        '#${farmer.farmerId}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmer.phone.isNotEmpty
                            ? farmer.phone
                            : farmer.email.isNotEmpty
                                ? farmer.email
                                : 'No contact details available',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FarmerStatPill(
                  icon: Icons.person_outline,
                  label: _roleLabel(farmer.role),
                  color: Colors.green.shade700,
                ),
                _FarmerStatPill(
                  icon: Icons.agriculture_outlined,
                  label: '${farmer.farmCount} farm(s)',
                  color: Colors.teal.shade700,
                ),
                _FarmerStatPill(
                  icon: Icons.park_outlined,
                  label: '${farmer.totalTrees} tree(s)',
                  color: Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (farmer.assignedFarms.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No farm links found in Firebase yet.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: farmer.assignedFarms
                      .take(3)
                      .map(
                        (farmLabel) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            farmLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF405243),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            const SizedBox(height: 14),
            ResponsiveWrapGrid(
              minChildWidth: 120,
              maxColumns: 3,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onCallTap,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
                OutlinedButton.icon(
                  onPressed: onEmailTap,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email'),
                ),
                ElevatedButton.icon(
                  onPressed: onDetailsTap,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStatCard extends StatelessWidget {
  const _TopStatCard({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2E8933)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5F7062),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerStatPill extends StatelessWidget {
  const _FarmerStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerDetailRow extends StatelessWidget {
  const _FarmerDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context, breakpoint: 360);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Farmer';
  }
  return normalized
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _managerLinkLabel(FarmManagerManagedFarmer farmer) {
  final managerName = farmer.farmManagerName.trim();
  final managerCode = farmer.farmManagerCode.trim();
  if (managerName.isEmpty && managerCode.isEmpty) {
    return 'Manager link not available';
  }
  if (managerName.isEmpty) {
    return managerCode;
  }
  if (managerCode.isEmpty) {
    return managerName;
  }
  return '$managerName ($managerCode)';
}
