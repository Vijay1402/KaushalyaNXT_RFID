import 'package:flutter/material.dart';

import '../../../../../shared/widgets/responsive_layout.dart';
import '../models/compare_model.dart';
import 'widgets/comparision_table.dart';
import 'widgets/filter_chip.dart';

class CompareResultScreen extends StatefulWidget {
  const CompareResultScreen({
    super.key,
    required this.trees,
    required this.initialFilters,
  });

  final List<Tree> trees;
  final List<String> initialFilters;

  @override
  State<CompareResultScreen> createState() => _CompareResultScreenState();
}

class _CompareResultScreenState extends State<CompareResultScreen> {
  late List<String> filters;

  @override
  void initState() {
    super.initState();
    filters = widget.initialFilters.isEmpty
        ? <String>['Yield', 'Health', 'Sync']
        : List<String>.from(widget.initialFilters);
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (filters.contains(filter)) {
        filters.remove(filter);
      } else {
        filters.add(filter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Compare Trees'),
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveLayout.pageInsets(
            context,
            top: 16,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Yield', 'Health', 'Sync']
                    .map(
                      (filter) => CustomFilterChip(
                        label: filter,
                        isSelected: filters.contains(filter),
                        onTap: () => _toggleFilter(filter),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.trees.length} selected tree(s)',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: filters.isEmpty
                      ? Center(
                          child: Text(
                            'Select at least one filter to compare the trees.',
                            style: TextStyle(color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: ComparisonTable(
                            trees: widget.trees,
                            filters: filters,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
