import 'package:flutter/material.dart';

import '../../../../../../shared/widgets/responsive_layout.dart';
import '../../models/compare_model.dart';

class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.trees,
    required this.filters,
  });

  final List<Tree> trees;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveLayout.isCompact(context, breakpoint: 420);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: compact ? 12 : 20,
        dataRowMinHeight: compact ? 56 : 48,
        columns: [
          const DataColumn(label: Text('Tree')),
          if (filters.contains('Yield')) const DataColumn(label: Text('Yield')),
          if (filters.contains('Health'))
            const DataColumn(label: Text('Health')),
          if (filters.contains('Sync')) const DataColumn(label: Text('Sync')),
        ],
        rows: trees.map((tree) {
          return DataRow(
            cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 110),
                  child: Text(tree.name),
                ),
              ),
              if (filters.contains('Yield')) DataCell(Text(tree.yield)),
              if (filters.contains('Health'))
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tree.health == 'Healthy'
                            ? Icons.check_circle
                            : Icons.warning,
                        color: tree.health == 'Healthy'
                            ? Colors.green
                            : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(tree.health),
                    ],
                  ),
                ),
              if (filters.contains('Sync')) DataCell(Text(tree.sync)),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}
