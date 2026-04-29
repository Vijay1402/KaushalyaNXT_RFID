import 'analytics_pdf_export_data.dart';
import 'analytics_pdf_exporter_stub.dart'
    if (dart.library.io) 'analytics_pdf_exporter_io.dart' as implementation;

Future<String?> exportFarmManagerAnalyticsPdf(
  FarmManagerAnalyticsExportData data,
) {
  return implementation.exportFarmManagerAnalyticsPdf(data);
}
