import 'package:flutter/material.dart';

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
        child: ListTile(
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
