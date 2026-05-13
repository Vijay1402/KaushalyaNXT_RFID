import 'package:flutter/material.dart';

import '../../../../../../shared/widgets/responsive_layout.dart';
import '../../models/compare_model.dart';

class TreeCard extends StatelessWidget {
  const TreeCard({
    super.key,
    required this.tree,
    required this.isSelected,
    required this.onTap,
  });

  final Tree tree;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveLayout.isCompact(context, breakpoint: 380);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: compact
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.park,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tree.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Yield: ${tree.yield}'),
                    Text('Health: ${tree.health}'),
                    Text('Sync: ${tree.sync}'),
                  ],
                ),
              )
            : ListTile(
                leading: const Icon(Icons.park, color: Colors.green, size: 32),
                title: Text(
                  tree.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yield: ${tree.yield}'),
                    Text('Health: ${tree.health}'),
                    Text('Sync: ${tree.sync}'),
                  ],
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.green : Colors.grey,
                ),
              ),
      ),
    );
  }
}
