import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../tree_details/tree_controller.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String selectedRange = 'Last 30 days';
  String healthMode = 'weekly';
  String? _selectedSpecies;
  String? _selectedHealth;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final treesAsync = ref.watch(treesProvider);
    final previewTrees = _normalizeTrees(treesAsync.valueOrNull ?? const []);
    final speciesOptions = _speciesOptions(previewTrees);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildHeader(user?.name ?? user?.email ?? 'Farmer'),
          _buildFilterRow(speciesOptions),
          Expanded(
            child: treesAsync.when(
              data: (rawTrees) {
                final trees = _filteredTrees(_normalizeTrees(rawTrees));
                final metrics = _buildMetrics(trees);
                final healthMetrics = _buildHealthMetrics(trees);
                final trend = _buildTrendSeries(trees, selectedRange);
                final activity = _buildActivityMetrics(trees);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: ResponsiveWrapGrid(
                          minChildWidth: 150,
                          maxColumns: 2,
                          children: [
                            _metricCard(
                              metrics.totalTreesLabel,
                              'Total Trees',
                            ),
                            _metricCard(
                              metrics.averageYieldLabel,
                              'Avg Yield',
                            ),
                            _metricCard(
                              metrics.healthyTreesLabel,
                              'Healthy',
                            ),
                            _metricCard(
                              metrics.atRiskTreesLabel,
                              'At risk',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final stackHeader =
                                      constraints.maxWidth < 380;
                                  final modeControls = Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _modeChip(
                                        'weekly',
                                        selected: healthMode == 'weekly',
                                        onTap: () {
                                          setState(() => healthMode = 'weekly');
                                        },
                                      ),
                                      _modeChip(
                                        'monthly',
                                        selected: healthMode == 'monthly',
                                        showArrow: true,
                                        onTap: _showHealthModeSheet,
                                      ),
                                    ],
                                  );

                                  if (stackHeader) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Health Distribution',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        modeControls,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Health Distribution',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      modeControls,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final stackChart = constraints.maxWidth < 380;
                                  final chart = SizedBox(
                                    height: 120,
                                    width: 120,
                                    child: CustomPaint(
                                      painter: _PieChartPainter(
                                        sections: [
                                          _PieSection(
                                            value: healthMetrics.healthyCount
                                                .toDouble(),
                                            color: Colors.green,
                                          ),
                                          _PieSection(
                                            value: healthMetrics
                                                .needsAttentionCount
                                                .toDouble(),
                                            color: Colors.orange,
                                          ),
                                          _PieSection(
                                            value: healthMetrics.atRiskCount
                                                .toDouble(),
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  final legend = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _legendRow(
                                        'Healthy',
                                        healthMetrics.healthyPercentLabel,
                                        Colors.green,
                                      ),
                                      const SizedBox(height: 10),
                                      _legendRow(
                                        'Needs Attention',
                                        healthMetrics
                                            .needsAttentionPercentLabel,
                                        Colors.orange,
                                      ),
                                      const SizedBox(height: 10),
                                      _legendRow(
                                        'At Risk',
                                        healthMetrics.atRiskPercentLabel,
                                        Colors.red,
                                      ),
                                    ],
                                  );

                                  if (stackChart) {
                                    return Column(
                                      children: [
                                        chart,
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: legend,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      chart,
                                      const SizedBox(width: 20),
                                      Expanded(child: legend),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final stackHeader =
                                      constraints.maxWidth < 360;
                                  final rangeChip = InkWell(
                                    onTap: _showRangeSheet,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            selectedRange,
                                            style: const TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  if (stackHeader) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Yield Trends',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        rangeChip,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Yield Trends',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      rangeChip,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _LineChartPainter(
                                    values: trend.values,
                                    bottomLabels: trend.bottomLabels,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final stackMetrics = constraints.maxWidth < 360;
                              final leading = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text(
                                      'RFID Activity',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                              final summary = Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Today: ${activity.todayCount}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Week: ${activity.weekCount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );

                              if (stackMetrics) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    leading,
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: summary,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: leading),
                                  const SizedBox(width: 10),
                                  summary,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load analytics right now.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String userLabel) {
    return Container(
      color: const Color(0xFF2E7D32),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.menu, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Analytics Dashboard',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _initials(userLabel),
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(List<String> speciesOptions) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _filterButton(Icons.filter_list, 'Filters'),
          InkWell(
            onTap: () => _showSelectionSheet(
              title: 'Species',
              options: speciesOptions,
              selectedValue: _selectedSpecies,
              allLabel: 'All Species',
              onSelected: (value) {
                setState(() => _selectedSpecies = value);
              },
            ),
            borderRadius: BorderRadius.circular(25),
            child: _filterButton(
              Icons.eco,
              _selectedSpecies ?? 'Species',
              isDropdown: true,
            ),
          ),
          InkWell(
            onTap: () => _showSelectionSheet(
              title: 'Health',
              options: const ['Healthy', 'Needs Attention', 'At Risk'],
              selectedValue: _selectedHealth,
              allLabel: 'All Health',
              onSelected: (value) {
                setState(() => _selectedHealth = value);
              },
            ),
            borderRadius: BorderRadius.circular(25),
            child: _filterButton(
              Icons.favorite,
              _selectedHealth ?? 'Health',
              isDropdown: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String value, String label) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
          ),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.park_rounded,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(IconData icon, String text, {bool isDropdown = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(text),
          if (isDropdown) const Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _legendRow(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value),
      ],
    );
  }

  Widget _modeChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    bool showArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF2E7D32) : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  List<_AnalyticsTree> _normalizeTrees(List<Map<String, dynamic>> rawTrees) {
    final seen = <String>{};
    final trees = <_AnalyticsTree>[];

    for (final raw in rawTrees) {
      final docId = (raw[treeDocIdField] ?? '').toString().trim();
      final treeId = (raw['treeId'] ?? '').toString().trim();
      final key = docId.isNotEmpty ? docId : treeId;
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);

      final ageYears = _asInt(raw['treeAge'] ?? raw['age']);
      final plantedOn = _parseDate(
            raw['plantingDate'] ?? raw['plantedOn'] ?? raw['createdAt'],
          ) ??
          (ageYears > 0
              ? DateTime.now().subtract(Duration(days: ageYears * 365))
              : null);

      trees.add(
        _AnalyticsTree(
          treeId: treeId.isEmpty ? docId : treeId,
          species: _speciesLabel(raw),
          health: _statusLabel(raw['healthStatus'] ?? raw['healthStatusName']),
          lastYieldKg: _asDouble(
            raw['lastYieldKg'] ?? raw['yieldKg'] ?? raw['yield'],
          ),
          plantedOn: plantedOn,
          lastActivityAt: _parseDate(
            raw['lastinspectiondate'] ??
                raw['lastInspectionDate'] ??
                raw['updatedAt'] ??
                raw['createdAt'],
          ),
        ),
      );
    }

    return trees;
  }

  List<String> _speciesOptions(List<_AnalyticsTree> trees) {
    final options = trees
        .map((tree) => tree.species)
        .where((species) => species.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return options;
  }

  List<_AnalyticsTree> _filteredTrees(List<_AnalyticsTree> trees) {
    return trees.where((tree) {
      if (_selectedSpecies != null && tree.species != _selectedSpecies) {
        return false;
      }
      if (_selectedHealth != null && tree.health != _selectedHealth) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  _MetricSummary _buildMetrics(List<_AnalyticsTree> trees) {
    final totalTrees = trees.length;
    final healthyTrees = trees.where((tree) => tree.health == 'Healthy').length;
    final atRiskTrees = trees.where((tree) => tree.health == 'At Risk').length;
    final totalYield = trees.fold<double>(
        0, (runningTotal, tree) => runningTotal + tree.lastYieldKg);
    final averageYield = totalTrees == 0 ? 0.0 : totalYield / totalTrees;

    return _MetricSummary(
      totalTreesLabel: NumberFormat.decimalPattern().format(totalTrees),
      averageYieldLabel: '${averageYield.toStringAsFixed(1)} kg',
      healthyTreesLabel: NumberFormat.decimalPattern().format(healthyTrees),
      atRiskTreesLabel: NumberFormat.decimalPattern().format(atRiskTrees),
    );
  }

  _HealthSummary _buildHealthMetrics(List<_AnalyticsTree> trees) {
    final sourceTrees = _healthScopedTrees(trees);
    final total = sourceTrees.length;
    final healthyCount =
        sourceTrees.where((tree) => tree.health == 'Healthy').length;
    final needsAttentionCount =
        sourceTrees.where((tree) => tree.health == 'Needs Attention').length;
    final atRiskCount =
        sourceTrees.where((tree) => tree.health == 'At Risk').length;

    String percentLabel(int count) {
      if (total == 0) {
        return '0%';
      }
      return '${((count / total) * 100).round()}%';
    }

    return _HealthSummary(
      healthyCount: healthyCount,
      needsAttentionCount: needsAttentionCount,
      atRiskCount: atRiskCount,
      healthyPercentLabel: percentLabel(healthyCount),
      needsAttentionPercentLabel: percentLabel(needsAttentionCount),
      atRiskPercentLabel: percentLabel(atRiskCount),
    );
  }

  List<_AnalyticsTree> _healthScopedTrees(List<_AnalyticsTree> trees) {
    final now = DateTime.now();
    final dayWindow = healthMode == 'weekly' ? 7 : 30;
    final scoped = trees.where((tree) {
      final lastActivityAt = tree.lastActivityAt;
      if (lastActivityAt == null || lastActivityAt.isAfter(now)) {
        return false;
      }
      return now.difference(lastActivityAt).inDays < dayWindow;
    }).toList(growable: false);

    return scoped.isEmpty ? trees : scoped;
  }

  _TrendSeries _buildTrendSeries(List<_AnalyticsTree> trees, String range) {
    final now = DateTime.now();
    final dayWindow = range == 'Last 7 days' ? 7 : 30;
    final bucketCount = range == 'Last 7 days' ? 7 : 14;
    final bucketWidth = dayWindow / bucketCount;
    final values = List<double>.filled(bucketCount, 0);
    final counts = List<int>.filled(bucketCount, 0);
    final labels = List<String>.filled(bucketCount, '');
    final overallAverageYield = trees.isEmpty
        ? 0.0
        : trees.fold<double>(
              0,
              (runningTotal, tree) => runningTotal + tree.lastYieldKg,
            ) /
            trees.length;

    for (final tree in trees) {
      final lastActivityAt = tree.lastActivityAt;
      if (lastActivityAt == null || lastActivityAt.isAfter(now)) {
        continue;
      }
      final daysAgo = now.difference(lastActivityAt).inDays;
      if (daysAgo < 0 || daysAgo >= dayWindow) {
        continue;
      }
      final bucket = (bucketCount - 1 - (daysAgo / bucketWidth).floor())
          .clamp(0, bucketCount - 1);
      values[bucket] += tree.lastYieldKg;
      counts[bucket] += 1;
    }

    for (var i = 0; i < bucketCount; i++) {
      if (counts[i] > 0) {
        values[i] = values[i] / counts[i];
      } else if (i > 0) {
        values[i] = values[i - 1];
      } else {
        values[i] = overallAverageYield;
      }
    }

    if (range == 'Last 7 days') {
      for (var i = 0; i < bucketCount; i++) {
        final date = now.subtract(Duration(days: bucketCount - 1 - i));
        if (i == bucketCount - 1) {
          labels[i] = 'Today';
        } else if (i.isEven) {
          labels[i] = DateFormat('E').format(date);
        }
      }
    } else {
      labels[0] = 'Week 1';
      labels[4] = 'Week 2';
      labels[8] = 'Week 3';
      labels[13] = 'Today';
    }

    return _TrendSeries(values: values, bottomLabels: labels);
  }

  _ActivitySummary _buildActivityMetrics(List<_AnalyticsTree> trees) {
    final now = DateTime.now();
    var todayCount = 0;
    var weekCount = 0;

    for (final tree in trees) {
      final lastActivityAt = tree.lastActivityAt;
      if (lastActivityAt == null || lastActivityAt.isAfter(now)) {
        continue;
      }

      if (_isSameDay(lastActivityAt, now)) {
        todayCount += 1;
      }
      if (now.difference(lastActivityAt).inDays < 7) {
        weekCount += 1;
      }
    }

    return _ActivitySummary(todayCount: todayCount, weekCount: weekCount);
  }

  Future<void> _showRangeSheet() {
    return _showSelectionSheet(
      title: 'Yield range',
      options: const ['Last 7 days', 'Last 30 days'],
      selectedValue: selectedRange,
      onSelected: (value) {
        if (value == null) {
          return;
        }
        setState(() => selectedRange = value);
      },
    );
  }

  Future<void> _showHealthModeSheet() {
    return _showSelectionSheet(
      title: 'Health distribution range',
      options: const ['weekly', 'monthly'],
      selectedValue: healthMode,
      onSelected: (value) {
        if (value == null) {
          return;
        }
        setState(() => healthMode = value);
      },
    );
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<String> options,
    required ValueChanged<String?> onSelected,
    String? selectedValue,
    String? allLabel,
  }) async {
    const allValue = '__all__';
    const dismissValue = '__dismiss__';

    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(dismissValue),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (allLabel != null)
                ListTile(
                  title: Text(allLabel),
                  trailing: selectedValue == null
                      ? const Icon(Icons.check, color: Color(0xFF2E7D32))
                      : null,
                  onTap: () => Navigator.of(context).pop(allValue),
                ),
              ...options.map(
                (option) => ListTile(
                  title: Text(option),
                  trailing: option == selectedValue
                      ? const Icon(Icons.check, color: Color(0xFF2E7D32))
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (value == null || value == dismissValue) {
      return;
    }
    onSelected(value == allValue ? null : value);
  }

  String _initials(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return 'F';
    }
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String _speciesLabel(Map<String, dynamic> raw) {
    final species = (raw['species'] ?? '').toString().trim();
    if (species.isNotEmpty) {
      return species;
    }
    final speciesCode = (raw['speciesCode'] ?? '').toString().trim();
    if (speciesCode.isNotEmpty) {
      return speciesCode;
    }
    return 'Unknown';
  }

  String _statusLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case '0':
      case 'healthy':
        return 'Healthy';
      case '1':
      case 'needsattention':
      case 'needs attention':
        return 'Needs Attention';
      case '2':
      case '3':
      case 'atrisk':
      case 'at risk':
      case 'sick':
      case 'unhealthy':
        return 'At Risk';
      default:
        return 'Healthy';
    }
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    if (raw is Map && raw['_seconds'] != null) {
      final seconds = (raw['_seconds'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return null;
  }

  int _asInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  double _asDouble(dynamic raw) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse((raw ?? '').toString()) ?? 0;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _AnalyticsTree {
  const _AnalyticsTree({
    required this.treeId,
    required this.species,
    required this.health,
    required this.lastYieldKg,
    required this.plantedOn,
    required this.lastActivityAt,
  });

  final String treeId;
  final String species;
  final String health;
  final double lastYieldKg;
  final DateTime? plantedOn;
  final DateTime? lastActivityAt;
}

class _MetricSummary {
  const _MetricSummary({
    required this.totalTreesLabel,
    required this.averageYieldLabel,
    required this.healthyTreesLabel,
    required this.atRiskTreesLabel,
  });

  final String totalTreesLabel;
  final String averageYieldLabel;
  final String healthyTreesLabel;
  final String atRiskTreesLabel;
}

class _HealthSummary {
  const _HealthSummary({
    required this.healthyCount,
    required this.needsAttentionCount,
    required this.atRiskCount,
    required this.healthyPercentLabel,
    required this.needsAttentionPercentLabel,
    required this.atRiskPercentLabel,
  });

  final int healthyCount;
  final int needsAttentionCount;
  final int atRiskCount;
  final String healthyPercentLabel;
  final String needsAttentionPercentLabel;
  final String atRiskPercentLabel;
}

class _TrendSeries {
  const _TrendSeries({
    required this.values,
    required this.bottomLabels,
  });

  final List<double> values;
  final List<String> bottomLabels;
}

class _ActivitySummary {
  const _ActivitySummary({
    required this.todayCount,
    required this.weekCount,
  });

  final int todayCount;
  final int weekCount;
}

class _PieSection {
  const _PieSection({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.sections});

  final List<_PieSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = sections.fold<double>(
      0,
      (runningTotal, section) => runningTotal + section.value,
    );

    if (total <= 0) {
      final paint = Paint()..color = Colors.grey.shade300;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2;

    for (final section in sections) {
      final sweepAngle = (section.value / total) * math.pi * 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sweepAngle, false)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = section.color
          ..style = PaintingStyle.fill,
      );

      startAngle += sweepAngle;
    }

    canvas.drawCircle(
      center,
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.bottomLabels,
  });

  final List<double> values;
  final List<String> bottomLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 34.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 30.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final safeValues = values.isEmpty ? <double>[0, 0] : values;
    var minValue = safeValues.reduce(math.min);
    var maxValue = safeValues.reduce(math.max);

    if (minValue == maxValue) {
      if (maxValue == 0) {
        maxValue = 10;
      } else {
        minValue = math.max(0, minValue * 0.8);
        maxValue = maxValue * 1.2;
      }
    } else {
      final padding = (maxValue - minValue) * 0.15;
      minValue = math.max(0, minValue - padding);
      maxValue = maxValue + padding;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final axisTextStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 10,
    );

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + (chartRect.height * i / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final labelValue = maxValue - ((maxValue - minValue) * i / 3);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelValue.toStringAsFixed(0),
          style: axisTextStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          chartRect.left - textPainter.width - 8,
          y - (textPainter.height / 2),
        ),
      );
    }

    final points = <Offset>[];
    final stepX = safeValues.length <= 1
        ? 0.0
        : chartRect.width / (safeValues.length - 1);

    for (var i = 0; i < safeValues.length; i++) {
      final normalizedY =
          (safeValues[i] - minValue) / math.max(maxValue - minValue, 0.001);
      points.add(
        Offset(
          chartRect.left + (stepX * i),
          chartRect.bottom - (normalizedY * chartRect.height),
        ),
      );
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      linePath.quadraticBezierTo(
        current.dx,
        current.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.25),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chartRect),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    for (final point in points) {
      canvas.drawCircle(
        point,
        4,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        point,
        3,
        Paint()..color = Colors.blue,
      );
    }

    for (var i = 0; i < bottomLabels.length && i < points.length; i++) {
      final label = bottomLabels[i];
      if (label.isEmpty) {
        continue;
      }
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 52);
      textPainter.paint(
        canvas,
        Offset(
          points[i].dx - (textPainter.width / 2),
          chartRect.bottom + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
