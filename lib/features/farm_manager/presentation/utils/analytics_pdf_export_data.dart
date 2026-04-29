class FarmManagerAnalyticsExportData {
  const FarmManagerAnalyticsExportData({
    required this.managerName,
    required this.generatedAt,
    required this.rangeLabel,
    required this.farmLabel,
    required this.healthModeLabel,
    required this.trendUnitLabel,
    required this.totalFarms,
    required this.totalTrees,
    required this.averageYieldKg,
    required this.healthyTrees,
    required this.needsAttentionTrees,
    required this.criticalTrees,
    required this.totalIssues,
    required this.criticalIssues,
    required this.farmHighlights,
    required this.issueHighlights,
    required this.trendHighlights,
    this.note = '',
  });

  final String managerName;
  final DateTime generatedAt;
  final String rangeLabel;
  final String farmLabel;
  final String healthModeLabel;
  final String trendUnitLabel;
  final int totalFarms;
  final int totalTrees;
  final double averageYieldKg;
  final int healthyTrees;
  final int needsAttentionTrees;
  final int criticalTrees;
  final int totalIssues;
  final int criticalIssues;
  final List<FarmManagerAnalyticsExportRow> farmHighlights;
  final List<FarmManagerAnalyticsExportRow> issueHighlights;
  final List<FarmManagerAnalyticsExportRow> trendHighlights;
  final String note;
}

class FarmManagerAnalyticsExportRow {
  const FarmManagerAnalyticsExportRow({
    required this.label,
    required this.value,
    this.detail = '',
  });

  final String label;
  final String value;
  final String detail;
}
