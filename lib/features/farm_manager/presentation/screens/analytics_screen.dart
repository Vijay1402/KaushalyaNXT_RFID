import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_paths.dart';
import '../../../auth/providers/auth_provider.dart';
import '../farm_manager_data.dart';
import '../utils/analytics_pdf_export_data.dart';
import '../utils/analytics_pdf_exporter.dart';
import '../../../farmer/tree_details/tree_controller.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  static const List<_RangeFilter> _ranges = [
    _RangeFilter(label: 'Last 7 days', days: 7),
    _RangeFilter(label: 'Last 30 days', days: 30),
    _RangeFilter(label: 'Last 90 days', days: 90),
  ];

  static const Map<String, int> _healthModeMonths = {
    'jan': DateTime.january,
    'feb': DateTime.february,
    'mar': DateTime.march,
    'apr': DateTime.april,
    'may': DateTime.may,
    'jun': DateTime.june,
    'jul': DateTime.july,
    'aug': DateTime.august,
    'sep': DateTime.september,
    'oct': DateTime.october,
    'nov': DateTime.november,
    'dec': DateTime.december,
  };

  String _selectedRangeLabel = 'Last 30 days';
  String _selectedHealthMode = 'weekly';
  String? _selectedFarmId;

  _RangeFilter get _selectedRange {
    for (final range in _ranges) {
      if (range.label == _selectedRangeLabel) {
        return range;
      }
    }
    return _ranges[1];
  }

  String get _selectedHealthModeLabel {
    if (_selectedHealthMode == 'weekly') {
      return 'Weekly';
    }
    final month = _healthModeMonths[_selectedHealthMode];
    if (month == null) {
      return 'Weekly';
    }
    return DateFormat.MMMM().format(DateTime(DateTime.now().year, month));
  }

  Future<void> _exportAnalytics(
    _AnalyticsViewData view,
    String managerName,
  ) async {
    final exportData = FarmManagerAnalyticsExportData(
      managerName: managerName,
      generatedAt: view.generatedAt,
      rangeLabel: view.rangeLabel,
      farmLabel: view.selectedFarmLabel,
      healthModeLabel: view.healthModeLabel,
      trendUnitLabel: view.trendUnitLabel,
      totalFarms: view.farmHighlights.length,
      totalTrees: view.totalTrees,
      averageYieldKg: view.averageYieldKg,
      healthyTrees: view.healthyTrees,
      needsAttentionTrees: view.needsAttentionTrees,
      criticalTrees: view.criticalTrees,
      totalIssues: view.totalIssues,
      criticalIssues: view.criticalIssues,
      farmHighlights: view.farmHighlights
          .take(5)
          .map(
            (farm) => FarmManagerAnalyticsExportRow(
              label: farm.name,
              value: '${farm.totalTrees} trees',
              detail:
                  'Health ${farm.healthPercent}% • Alerts ${farm.alertCount} • ${farm.location}',
            ),
          )
          .toList(growable: false),
      issueHighlights: view.issueHighlights
          .take(5)
          .map(
            (issue) => FarmManagerAnalyticsExportRow(
              label: issue.title,
              value: issue.severity,
              detail:
                  '${issue.farmLabel} • ${issue.note.isEmpty ? "No note" : issue.note}',
            ),
          )
          .toList(growable: false),
      trendHighlights: view.trendPoints
          .map(
            (point) => FarmManagerAnalyticsExportRow(
              label: point.label,
              value: point.value.toStringAsFixed(1),
              detail: view.trendUnitLabel,
            ),
          )
          .toList(growable: false),
      note: view.usedRangeFallback
          ? 'No tree activity matched ${view.rangeLabel}; the screen fell back to all available trees in the selected farm scope.'
          : '',
    );

    try {
      final path = await exportFarmManagerAnalyticsPdf(exportData);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (path == null || path.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('PDF export is not available on this platform yet.'),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Analytics PDF saved to $path'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export analytics: $error'),
        ),
      );
    }
  }

  void _showRangeOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _ranges
              .map(
                (range) => ListTile(
                  title: Text(range.label),
                  trailing: range.label == _selectedRangeLabel
                      ? const Icon(Icons.check_circle, color: Color(0xFF2E8933))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedRangeLabel = range.label;
                    });
                    context.pop();
                  },
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _showFarmOptions(List<FarmManagerFarm> farms) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Farms'),
              subtitle: Text('${farms.length} managed farm(s)'),
              trailing: _selectedFarmId == null
                  ? const Icon(Icons.check_circle, color: Color(0xFF2E8933))
                  : null,
              onTap: () {
                setState(() {
                  _selectedFarmId = null;
                });
                context.pop();
              },
            ),
            ...farms.map(
              (farm) => ListTile(
                title: Text(farm.name),
                subtitle: Text(farm.location),
                trailing: _selectedFarmId == farm.id
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E8933))
                    : Text('${farm.totalTrees}'),
                onTap: () {
                  setState(() {
                    _selectedFarmId = farm.id;
                  });
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthModeOptions() {
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _HealthModeTile(
              label: 'Weekly',
              selected: _selectedHealthMode == 'weekly',
              onTap: () {
                setState(() {
                  _selectedHealthMode = 'weekly';
                });
                context.pop();
              },
            ),
            ..._healthModeMonths.entries.map(
              (entry) => _HealthModeTile(
                label:
                    DateFormat.MMMM().format(DateTime(now.year, entry.value)),
                selected: _selectedHealthMode == entry.key,
                onTap: () {
                  setState(() {
                    _selectedHealthMode = entry.key;
                  });
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final managerName =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Manager';
    final analyticsAsync = ref.watch(farmManagerAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      bottomNavigationBar: _FarmManagerAnalyticsBottomNav(
        onHomeTap: () => context.go(RoutePaths.farmManagerHome),
        onFarmsTap: () => context.push(RoutePaths.farmManagerFarms),
        onScanTap: () => context.push('/scan'),
        onAnalyticsTap: () {},
        onProfileTap: () => context.push('/profile'),
      ),
      body: SafeArea(
        child: analyticsAsync.when(
          loading: () => Column(
            children: [
              _AnalyticsHeader(
                managerName: managerName,
                lastUpdatedLabel: 'Loading analytics...',
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (error, _) => Column(
            children: [
              _AnalyticsHeader(
                managerName: managerName,
                lastUpdatedLabel: 'Unable to load analytics',
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load analytics data: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (data) {
            final view = _AnalyticsViewData.from(
              data: data,
              selectedFarmId: _selectedFarmId,
              range: _selectedRange,
              healthMode: _selectedHealthMode,
              healthModeLabel: _selectedHealthModeLabel,
            );

            return Column(
              children: [
                _AnalyticsHeader(
                  managerName: managerName,
                  lastUpdatedLabel:
                      'Updated ${DateFormat('dd MMM, hh:mm a').format(view.generatedAt)}',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ActionChip(
                              label: view.rangeLabel,
                              icon: Icons.calendar_month_rounded,
                              onTap: _showRangeOptions,
                            ),
                            const SizedBox(width: 10),
                            _ActionChip(
                              label: view.selectedFarmLabel,
                              icon: Icons.agriculture_rounded,
                              onTap: () => _showFarmOptions(data.farms),
                            ),
                            const SizedBox(width: 10),
                            _ActionChip(
                              label: 'Export PDF',
                              icon: Icons.picture_as_pdf_rounded,
                              onTap: () => _exportAnalytics(view, managerName),
                            ),
                          ],
                        ),
                      ),
                      if (view.usedRangeFallback) ...[
                        const SizedBox(height: 14),
                        const _FallbackNotice(),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Visible Trees',
                              value: '${view.totalTrees}',
                              subtitle: 'Current range',
                              icon: Icons.park_rounded,
                              accent: const Color(0xFF2E8933),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Avg Yield',
                              value:
                                  '${view.averageYieldKg.toStringAsFixed(1)} kg',
                              subtitle: 'Per tree',
                              icon: Icons.grass_rounded,
                              accent: const Color(0xFF356F39),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Healthy',
                              value: '${view.healthyTrees}',
                              subtitle: 'Good health',
                              icon: Icons.favorite_rounded,
                              accent: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'At Risk',
                              value: '${view.criticalTrees}',
                              subtitle:
                                  '${view.criticalIssues} critical issue(s)',
                              icon: Icons.warning_amber_rounded,
                              accent: const Color(0xFFD66A1F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _HealthDistributionCard(
                        key: ValueKey(
                          'health-${view.rangeLabel}-${view.selectedFarmLabel}-${view.healthModeLabel}-${view.totalTrees}',
                        ),
                        breakdown: view.healthBreakdown,
                        healthModeLabel: view.healthModeLabel,
                        onSelectMode: _showHealthModeOptions,
                      ),
                      const SizedBox(height: 18),
                      _TrendCard(
                        key: ValueKey(
                          'trend-${view.rangeLabel}-${view.selectedFarmLabel}-${view.totalTrees}',
                        ),
                        rangeLabel: view.rangeLabel,
                        trendPoints: view.trendPoints,
                        trendUnitLabel: view.trendUnitLabel,
                      ),
                      const SizedBox(height: 18),
                      _FarmHighlightsCard(
                        farms: view.farmHighlights,
                        selectedFarmLabel: view.selectedFarmLabel,
                      ),
                      const SizedBox(height: 18),
                      _IssueHighlightsCard(
                        issues: view.issueHighlights,
                        totalIssues: view.totalIssues,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsViewData {
  const _AnalyticsViewData({
    required this.generatedAt,
    required this.rangeLabel,
    required this.selectedFarmLabel,
    required this.healthModeLabel,
    required this.totalTrees,
    required this.averageYieldKg,
    required this.healthyTrees,
    required this.needsAttentionTrees,
    required this.criticalTrees,
    required this.totalIssues,
    required this.criticalIssues,
    required this.usedRangeFallback,
    required this.healthBreakdown,
    required this.trendPoints,
    required this.trendUnitLabel,
    required this.farmHighlights,
    required this.issueHighlights,
  });

  final DateTime generatedAt;
  final String rangeLabel;
  final String selectedFarmLabel;
  final String healthModeLabel;
  final int totalTrees;
  final double averageYieldKg;
  final int healthyTrees;
  final int needsAttentionTrees;
  final int criticalTrees;
  final int totalIssues;
  final int criticalIssues;
  final bool usedRangeFallback;
  final _HealthBreakdown healthBreakdown;
  final List<_TrendPoint> trendPoints;
  final String trendUnitLabel;
  final List<FarmManagerFarm> farmHighlights;
  final List<FarmManagerIssue> issueHighlights;

  factory _AnalyticsViewData.from({
    required FarmManagerAnalyticsData data,
    required String? selectedFarmId,
    required _RangeFilter range,
    required String healthMode,
    required String healthModeLabel,
  }) {
    final selectedFarm = _findFarm(data.farms, selectedFarmId);
    final farmLabel = selectedFarm?.name ?? 'All Farms';
    final allFarmTrees = selectedFarm == null
        ? data.trees
        : data.trees
            .where((tree) => _treeMatchesFarm(tree, selectedFarm))
            .toList();
    final rangeTrees = _treesWithinRange(allFarmTrees, range.days);
    final usedRangeFallback = allFarmTrees.isNotEmpty && rangeTrees.isEmpty;
    final visibleTrees = usedRangeFallback ? allFarmTrees : rangeTrees;
    final allIssues = selectedFarm == null
        ? data.issues
        : data.issues
            .where((issue) => _issueMatchesFarm(issue, selectedFarm))
            .toList();
    final rangeIssues = _issuesWithinRange(allIssues, range.days);
    final visibleIssues =
        allIssues.isNotEmpty && rangeIssues.isEmpty ? allIssues : rangeIssues;

    final healthyTrees = visibleTrees
        .where((tree) => healthLabel(tree['healthStatus']) == 'Healthy')
        .length;
    final needsAttentionTrees = visibleTrees
        .where((tree) => healthLabel(tree['healthStatus']) == 'Needs Attention')
        .length;
    final criticalTrees = visibleTrees
        .where(
          (tree) => const {'At Risk', 'Critical'}
              .contains(healthLabel(tree['healthStatus'])),
        )
        .length;
    final averageYieldKg = visibleTrees.isEmpty
        ? 0.0
        : visibleTrees.fold<double>(0, (sum, tree) => sum + _yieldOf(tree)) /
            visibleTrees.length;
    final healthModeTrees = _treesForHealthMode(visibleTrees, healthMode);
    final breakdownTrees = healthModeTrees.isEmpty && visibleTrees.isNotEmpty
        ? visibleTrees
        : healthModeTrees;
    final healthBreakdown = _HealthBreakdown.fromTrees(breakdownTrees);
    final trend = _TrendSeries.fromTrees(
      visibleTrees: visibleTrees,
      range: range,
    );
    final farmHighlights = selectedFarm == null
        ? ([...data.farms]..sort(
            (left, right) => right.totalTrees.compareTo(left.totalTrees),
          ))
        : data.farms.where((farm) => farm.id == selectedFarm.id).toList();
    final issueHighlights = [...visibleIssues]..sort((left, right) {
        final leftWeight = _issueSeverityWeight(left.severity);
        final rightWeight = _issueSeverityWeight(right.severity);
        if (leftWeight != rightWeight) {
          return rightWeight.compareTo(leftWeight);
        }
        final rightTime =
            right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final leftTime =
            left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightTime.compareTo(leftTime);
      });

    return _AnalyticsViewData(
      generatedAt: data.generatedAt,
      rangeLabel: range.label,
      selectedFarmLabel: farmLabel,
      healthModeLabel: healthModeLabel,
      totalTrees: visibleTrees.length,
      averageYieldKg: averageYieldKg,
      healthyTrees: healthyTrees,
      needsAttentionTrees: needsAttentionTrees,
      criticalTrees: criticalTrees,
      totalIssues: visibleIssues.length,
      criticalIssues: visibleIssues
          .where((issue) => issue.severity.toLowerCase() == 'critical')
          .length,
      usedRangeFallback: usedRangeFallback,
      healthBreakdown: healthBreakdown,
      trendPoints: trend.points,
      trendUnitLabel: trend.unitLabel,
      farmHighlights: farmHighlights,
      issueHighlights: issueHighlights.take(4).toList(growable: false),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.managerName,
    required this.lastUpdatedLabel,
  });

  final String managerName;
  final String lastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF2E8933),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastUpdatedLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initialsFor(managerName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8E0D7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2E8933)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF26412B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBD7BE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2E8933),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No tree activity matched the selected range, so the dashboard is showing all available trees for this farm scope.',
              style: TextStyle(
                height: 1.4,
                color: Color(0xFF27462D),
              ),
            ),
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
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5A4E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A21),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF708174),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthDistributionCard extends StatelessWidget {
  const _HealthDistributionCard({
    super.key,
    required this.breakdown,
    required this.healthModeLabel,
    required this.onSelectMode,
  });

  final _HealthBreakdown breakdown;
  final String healthModeLabel;
  final VoidCallback onSelectMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Health Distribution',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A21),
                  ),
                ),
              ),
              InkWell(
                onTap: onSelectMode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        healthModeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 144,
                height: 144,
                child: TweenAnimationBuilder<double>(
                  key: key,
                  duration: const Duration(milliseconds: 700),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _DonutChartPainter(
                        breakdown: breakdown,
                        progress: value,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(
                      label: 'Healthy',
                      value: breakdown.healthy,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      label: 'Needs Attention',
                      value: breakdown.needsAttention,
                      color: const Color(0xFFD9922B),
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      label: 'Critical',
                      value: breakdown.critical,
                      color: const Color(0xFFE15D4A),
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

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF304133),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF1F2A21),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    super.key,
    required this.rangeLabel,
    required this.trendPoints,
    required this.trendUnitLabel,
  });

  final String rangeLabel;
  final List<_TrendPoint> trendPoints;
  final String trendUnitLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Yield & Activity Trend',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A21),
                  ),
                ),
              ),
              Text(
                rangeLabel,
                style: const TextStyle(
                  color: Color(0xFF2E8933),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trendUnitLabel,
            style: const TextStyle(
              color: Color(0xFF708174),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: TweenAnimationBuilder<double>(
              key: key,
              duration: const Duration(milliseconds: 700),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _TrendLinePainter(
                    points: trendPoints,
                    progress: value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: trendPoints
                .map(
                  (point) => Expanded(
                    child: Text(
                      point.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6E7F72),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FarmHighlightsCard extends StatelessWidget {
  const _FarmHighlightsCard({
    required this.farms,
    required this.selectedFarmLabel,
  });

  final List<FarmManagerFarm> farms;
  final String selectedFarmLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedFarmLabel == 'All Farms'
                ? 'Managed Farms'
                : '$selectedFarmLabel Summary',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A21),
            ),
          ),
          const SizedBox(height: 14),
          if (farms.isEmpty)
            const Text(
              'No farms are visible for this manager yet.',
              style: TextStyle(
                color: Color(0xFF708174),
              ),
            )
          else
            ...farms.take(4).map(
                  (farm) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                farm.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2A21),
                                ),
                              ),
                            ),
                            Text(
                              '${farm.healthPercent}%',
                              style: const TextStyle(
                                color: Color(0xFF2E8933),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${farm.location} • ${farm.totalTrees} trees • ${farm.alertCount} alert(s)',
                          style: const TextStyle(
                            color: Color(0xFF708174),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: farm.totalTrees == 0
                                ? 0
                                : farm.healthPercent / 100,
                            minHeight: 10,
                            color: const Color(0xFF59C154),
                            backgroundColor: const Color(0xFFE7EFE6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _IssueHighlightsCard extends StatelessWidget {
  const _IssueHighlightsCard({
    required this.issues,
    required this.totalIssues,
  });

  final List<FarmManagerIssue> issues;
  final int totalIssues;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Issue Highlights',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A21),
                  ),
                ),
              ),
              Text(
                '$totalIssues visible',
                style: const TextStyle(
                  color: Color(0xFF708174),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (issues.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5EA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No active issues are visible in this analytics scope.',
                style: TextStyle(
                  color: Color(0xFF27462D),
                ),
              ),
            )
          else
            ...issues.map(
              (issue) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _issueBackground(issue.severity),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: issueSeverityColor(issue.severity),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2A21),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            issue.note.isEmpty ? 'No note added' : issue.note,
                            style: const TextStyle(
                              color: Color(0xFF39453B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${issue.farmLabel} • ${issue.severity}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6E7F72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthModeTile extends StatelessWidget {
  const _HealthModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF2E8933))
          : null,
      onTap: onTap,
    );
  }
}

class _FarmManagerAnalyticsBottomNav extends StatelessWidget {
  const _FarmManagerAnalyticsBottomNav({
    required this.onHomeTap,
    required this.onFarmsTap,
    required this.onScanTap,
    required this.onAnalyticsTap,
    required this.onProfileTap,
  });

  final VoidCallback onHomeTap;
  final VoidCallback onFarmsTap;
  final VoidCallback onScanTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BottomNavItem(
              icon: Icons.home,
              label: 'Home',
              onTap: onHomeTap,
            ),
            _BottomNavItem(
              icon: Icons.agriculture_outlined,
              label: 'My Farms',
              onTap: onFarmsTap,
            ),
            GestureDetector(
              onTap: onScanTap,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF59C154),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            _BottomNavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              active: true,
              onTap: onAnalyticsTap,
            ),
            _BottomNavItem(
              icon: Icons.person,
              label: 'Profile',
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF59C154) : Colors.grey.shade500;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.breakdown,
    required this.progress,
  });

  final _HealthBreakdown breakdown;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 18.0;

    final basePaint = Paint()
      ..color = const Color(0xFFE8EFE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, basePaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = breakdown.total == 0 ? 1 : breakdown.total;
    final segments = [
      (
        value: breakdown.healthy / total,
        color: const Color(0xFF4CAF50),
      ),
      (
        value: breakdown.needsAttention / total,
        color: const Color(0xFFD9922B),
      ),
      (
        value: breakdown.critical / total,
        color: const Color(0xFFE15D4A),
      ),
    ];

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) {
        continue;
      }
      final sweep = segment.value * (math.pi * 2) * progress;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, startAngle, math.max(sweep - 0.06, 0.02), false, paint);
      startAngle += sweep;
    }

    final percent = breakdown.total == 0
        ? 0
        : ((breakdown.healthy / breakdown.total) * 100).round();
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$percent%\n',
            style: const TextStyle(
              color: Color(0xFF1F2A21),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(
            text: 'Healthy',
            style: TextStyle(
              color: Color(0xFF708174),
              fontSize: 12,
            ),
          ),
        ],
      ),
    )..layout(maxWidth: 90);

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.breakdown != breakdown ||
        oldDelegate.progress != progress;
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({
    required this.points,
    required this.progress,
  });

  final List<_TrendPoint> points;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 18.0;
    const verticalPadding = 16.0;
    final chartWidth = size.width - (horizontalPadding * 2);
    final chartHeight = size.height - (verticalPadding * 2);
    const origin = Offset(horizontalPadding, verticalPadding);

    final gridPaint = Paint()
      ..color = const Color(0xFFE6ECE5)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = origin.dy + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + chartWidth, y),
        gridPaint,
      );
    }

    if (points.isEmpty) {
      return;
    }

    final maxValue = points.fold<double>(
      0,
      (current, point) => point.value > current ? point.value : current,
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final offsets = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = origin.dx + (stepX * index);
      final normalized = (point.value / safeMax).clamp(0.0, 1.0);
      final y = origin.dy + chartHeight - (chartHeight * normalized * progress);
      offsets.add(Offset(x, y));
    }

    final linePath = Path();
    for (var index = 0; index < offsets.length; index++) {
      final point = offsets[index];
      if (index == 0) {
        linePath.moveTo(point.dx, point.dy);
        continue;
      }
      final previous = offsets[index - 1];
      final controlX = (previous.dx + point.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        point.dy,
        point.dx,
        point.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(origin.dx + chartWidth, origin.dy + chartHeight)
      ..lineTo(origin.dx, origin.dy + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x553B8F45),
          Color(0x113B8F45),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(origin.dx, origin.dy, chartWidth, chartHeight),
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF2E8933)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF2E8933);
    for (final point in offsets) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(
        point,
        8,
        Paint()..color = const Color(0x332E8933),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.progress != progress;
  }
}

class _RangeFilter {
  const _RangeFilter({
    required this.label,
    required this.days,
  });

  final String label;
  final int days;
}

class _HealthBreakdown {
  const _HealthBreakdown({
    required this.healthy,
    required this.needsAttention,
    required this.critical,
  });

  factory _HealthBreakdown.fromTrees(List<Map<String, dynamic>> trees) {
    var healthy = 0;
    var needsAttention = 0;
    var critical = 0;

    for (final tree in trees) {
      switch (healthLabel(tree['healthStatus'])) {
        case 'Healthy':
          healthy++;
        case 'Needs Attention':
          needsAttention++;
        case 'At Risk':
        case 'Critical':
          critical++;
        default:
          break;
      }
    }

    return _HealthBreakdown(
      healthy: healthy,
      needsAttention: needsAttention,
      critical: critical,
    );
  }

  final int healthy;
  final int needsAttention;
  final int critical;

  int get total => healthy + needsAttention + critical;
}

class _TrendSeries {
  const _TrendSeries({
    required this.points,
    required this.unitLabel,
  });

  factory _TrendSeries.fromTrees({
    required List<Map<String, dynamic>> visibleTrees,
    required _RangeFilter range,
  }) {
    final useYield = visibleTrees.any((tree) => _yieldOf(tree) > 0);
    final bucketCount = range.days <= 7 ? range.days : 6;
    final bucketSize = math.max(1, (range.days / bucketCount).ceil());
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final rangeStart = startOfToday.subtract(Duration(days: range.days - 1));
    final points = <_TrendPoint>[];

    for (var index = 0; index < bucketCount; index++) {
      final bucketStart = rangeStart.add(Duration(days: bucketSize * index));
      final bucketEnd = index == bucketCount - 1
          ? startOfToday.add(const Duration(days: 1))
          : bucketStart.add(Duration(days: bucketSize));
      final bucketTrees = visibleTrees.where((tree) {
        final date = _treeDate(tree);
        if (date == null) {
          return false;
        }
        return !date.isBefore(bucketStart) && date.isBefore(bucketEnd);
      }).toList(growable: false);

      final value = useYield
          ? bucketTrees.isEmpty
              ? 0.0
              : bucketTrees.fold<double>(
                      0, (sum, tree) => sum + _yieldOf(tree)) /
                  bucketTrees.length
          : bucketTrees.length.toDouble();
      final label = range.days <= 7
          ? DateFormat('EEE').format(bucketStart)
          : DateFormat('d MMM').format(bucketStart);

      points.add(
        _TrendPoint(
          label: label,
          value: value,
        ),
      );
    }

    return _TrendSeries(
      points: points,
      unitLabel: useYield ? 'Average yield in kg' : 'Updated trees',
    );
  }

  final List<_TrendPoint> points;
  final String unitLabel;
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

FarmManagerFarm? _findFarm(List<FarmManagerFarm> farms, String? farmId) {
  if (farmId == null || farmId.trim().isEmpty) {
    return null;
  }
  for (final farm in farms) {
    if (farm.id == farmId) {
      return farm;
    }
  }
  return null;
}

bool _treeMatchesFarm(
  Map<String, dynamic> tree,
  FarmManagerFarm farm,
) {
  if (farmIdFromTree(tree) == farm.id) {
    return true;
  }

  final treeFarmName = farmNameFromTree(tree).trim().toLowerCase();
  final farmName = farm.name.trim().toLowerCase();
  if (treeFarmName.isNotEmpty && treeFarmName == farmName) {
    return true;
  }

  final treeLocation = (tree['location'] ?? '').toString().trim().toLowerCase();
  final farmLocation = farm.location.trim().toLowerCase();
  return treeLocation.isNotEmpty && treeLocation == farmLocation;
}

bool _issueMatchesFarm(
  FarmManagerIssue issue,
  FarmManagerFarm farm,
) {
  if (issue.farmId.trim().isNotEmpty && issue.farmId == farm.id) {
    return true;
  }

  final label = issue.farmLabel.trim().toLowerCase();
  return label == farm.name.trim().toLowerCase() ||
      label == farm.location.trim().toLowerCase();
}

List<Map<String, dynamic>> _treesWithinRange(
  List<Map<String, dynamic>> trees,
  int days,
) {
  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: math.max(days - 1, 0)));
  return trees.where((tree) {
    final date = _treeDate(tree);
    return date != null && !date.isBefore(cutoff);
  }).toList(growable: false);
}

List<FarmManagerIssue> _issuesWithinRange(
  List<FarmManagerIssue> issues,
  int days,
) {
  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: math.max(days - 1, 0)));
  return issues.where((issue) {
    final date = issue.createdAt;
    return date != null && !date.isBefore(cutoff);
  }).toList(growable: false);
}

List<Map<String, dynamic>> _treesForHealthMode(
  List<Map<String, dynamic>> trees,
  String healthMode,
) {
  if (healthMode == 'weekly') {
    return trees;
  }
  final month = _AnalyticsScreenState._healthModeMonths[healthMode];
  if (month == null) {
    return trees;
  }
  final currentYear = DateTime.now().year;
  return trees.where((tree) {
    final date = _treeDate(tree);
    return date != null && date.year == currentYear && date.month == month;
  }).toList(growable: false);
}

DateTime? _treeDate(Map<String, dynamic> tree) {
  return parseDateTime(
    tree['updatedAt'] ??
        tree['lastinspectiondate'] ??
        tree['lastInspectionDate'] ??
        tree['createdAt'],
  );
}

double _yieldOf(Map<String, dynamic> tree) {
  return asDouble(tree['lastYieldKg'] ?? tree['yieldKg'] ?? tree['yield'] ?? 0);
}

int _issueSeverityWeight(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'critical':
      return 3;
    case 'monitoring':
      return 2;
    case 'open':
      return 1;
    case 'resolved':
      return 0;
    default:
      return 1;
  }
}

Color _issueBackground(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'critical':
      return const Color(0xFFFDE7E5);
    case 'monitoring':
      return const Color(0xFFFFF3E0);
    case 'resolved':
      return const Color(0xFFE9F5EA);
    default:
      return const Color(0xFFF2F4F1);
  }
}
