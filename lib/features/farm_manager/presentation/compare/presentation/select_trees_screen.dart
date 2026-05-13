import 'package:flutter/material.dart';

import '../../../../../shared/widgets/responsive_layout.dart';
import '../models/compare_model.dart';
import 'compare_screen.dart';
import 'widgets/filter_chip.dart';
import 'widgets/tree_card.dart';

class SelectTreesScreen extends StatefulWidget {
  const SelectTreesScreen({
    super.key,
    required this.trees,
    this.initiallySelectedTreeIds = const <String>{},
  });

  final List<Tree> trees;
  final Set<String> initiallySelectedTreeIds;

  @override
  State<SelectTreesScreen> createState() => _SelectTreesScreenState();
}

class _SelectTreesScreenState extends State<SelectTreesScreen> {
  late Set<String> selectedTreeIds;
  List<String> filters = <String>['Yield', 'Health', 'Sync'];

  @override
  void initState() {
    super.initState();
    selectedTreeIds = Set<String>.from(widget.initiallySelectedTreeIds);
  }

  void _toggleTree(String treeId) {
    setState(() {
      if (selectedTreeIds.contains(treeId)) {
        selectedTreeIds.remove(treeId);
      } else {
        selectedTreeIds.add(treeId);
      }
    });
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
    final selectedTrees = widget.trees
        .where((tree) => selectedTreeIds.contains(tree.id))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Select Trees'),
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
                'Filters',
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
                '${selectedTrees.length} selected tree(s)',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.trees.isEmpty
                    ? Center(
                        child: Text(
                          'No trees are available for comparison.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.trees.length,
                        itemBuilder: (context, index) {
                          final tree = widget.trees[index];
                          final isSelected = selectedTreeIds.contains(tree.id);

                          return TreeCard(
                            tree: tree,
                            isSelected: isSelected,
                            onTap: () => _toggleTree(tree.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedTrees.length < 2
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CompareResultScreen(
                                trees: selectedTrees,
                                initialFilters: filters,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Compare'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
