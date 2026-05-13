// ============================================================
//  lib/features/farmer/tree_details/tree_predictions_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';
import '../../../shared/widgets/responsive_layout.dart';

class TreePredictionsScreen extends StatelessWidget {
  final Tree tree;
  const TreePredictionsScreen({super.key, required this.tree});

  static const _green1 = Color(0xFF1E4D2B);
  static const _green2 = Color(0xFF2D6A3F);

  @override
  Widget build(BuildContext context) {
    final yieldKg = tree.maintenanceRecords.length * 48 + 50;
    final nextYieldKg = (yieldKg * 1.08).round();
    final horizontalPadding = ResponsiveLayout.pagePadding(context);
    final healthScore = tree.currentStatus == TreeHealthStatus.healthy
        ? 92
        : tree.currentStatus == TreeHealthStatus.needsAttention
            ? 65
            : tree.currentStatus == TreeHealthStatus.atRisk
                ? 40
                : 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('${tree.name} — Predictions'),
        backgroundColor: _green1,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AI insight banner ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade800, Colors.green.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 280;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI-Powered Predictions',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on ${tree.ageInYears} years of data for ${tree.name}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  );

                  if (!isCompact) {
                    return Row(
                      children: [
                        const Icon(Icons.insights, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(child: copy),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.insights, color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      copy,
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ── Yield prediction ─────────────────────────────────
            _sectionTitle('Yield Forecast'),
            const SizedBox(height: 10),
            ResponsiveWrapGrid(
              minChildWidth: 160,
              maxColumns: 2,
              spacing: 10,
              runSpacing: 10,
              children: [
                _predictionBox(
                  'This Season',
                  '$yieldKg kg',
                  Icons.agriculture,
                  Colors.green,
                  'Current estimate',
                ),
                _predictionBox(
                  'Next Season',
                  '$nextYieldKg kg',
                  Icons.trending_up,
                  Colors.blue,
                  '+8% projected',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Health score ─────────────────────────────────────
            _sectionTitle('Health Score Prediction'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 260;
                      final scoreText = Text(
                        '$healthScore / 100',
                        style: TextStyle(
                          color: healthScore > 70
                              ? Colors.green
                              : healthScore > 40
                                  ? Colors.orange
                                  : Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      );

                      if (!isCompact) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Health Score',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            scoreText,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Health Score',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          scoreText,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: healthScore / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: healthScore > 70
                          ? Colors.green
                          : healthScore > 40
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    healthScore > 70
                        ? 'Tree is in excellent condition. Continue current care routine.'
                        : healthScore > 40
                            ? 'Tree needs attention. Schedule inspection within 2 weeks.'
                            : 'Tree is at risk. Immediate care required.',
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Maintenance predictions ──────────────────────────
            _sectionTitle('Upcoming Care Recommendations'),
            const SizedBox(height: 10),
            ...[
              {
                'title': 'Pruning',
                'due': 'In 2 weeks',
                'priority': 'Medium',
                'color': Colors.orange
              },
              {
                'title': 'Fertilization',
                'due': 'In 1 month',
                'priority': 'Low',
                'color': Colors.green
              },
              {
                'title': 'Pest Inspection',
                'due': 'In 3 weeks',
                'priority': 'High',
                'color': Colors.red
              },
              {
                'title': 'Soil pH Testing',
                'due': 'In 6 weeks',
                'priority': 'Low',
                'color': Colors.green
              },
            ].map((item) => _recommendationTile(
                  item['title'] as String,
                  item['due'] as String,
                  item['priority'] as String,
                  item['color'] as Color,
                )),

            const SizedBox(height: 16),

            // ── Risk assessment ──────────────────────────────────
            _sectionTitle('Risk Assessment'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  _riskRow('Pest Risk', 0.25, Colors.orange),
                  const SizedBox(height: 10),
                  _riskRow('Disease Risk', 0.15, Colors.red),
                  const SizedBox(height: 10),
                  _riskRow('Drought Risk', 0.40, Colors.amber),
                  const SizedBox(height: 10),
                  _riskRow('Yield Drop Risk', 0.20, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: _green2, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2E1C))),
    ]);
  }

  Widget _predictionBox(
      String label, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _recommendationTile(
      String title, String due, String priority, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        final priorityChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.eco, color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                due,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    priorityChip,
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.eco, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            due,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    priorityChip,
                  ],
                ),
        );
      },
    );
  }

  Widget _riskRow(String label, double value, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;

        if (!isCompact) {
          return Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
