import 'package:flutter/material.dart';

class CustomFilterChip extends StatelessWidget {
  const CustomFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  IconData getIcon() {
    switch (label) {
      case 'Yield':
        return Icons.bar_chart;
      case 'Health':
        return Icons.favorite;
      case 'Sync':
        return Icons.sync;
      default:
        return Icons.filter_alt;
    }
  }

  Color getColor() {
    switch (label) {
      case 'Yield':
        return Colors.blue;
      case 'Health':
        return Colors.green;
      case 'Sync':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getIcon(),
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            if (isSelected)
              const Icon(Icons.close, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
