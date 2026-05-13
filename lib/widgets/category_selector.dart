import 'package:flutter/material.dart';
import '../models/category.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> parentCategories;
  final List<Category> childCategories;
  final int? selectedParentId;
  final int? selectedChildId;
  final ValueChanged<int> onParentSelected;
  final ValueChanged<int?>? onChildSelected;

  const CategorySelector({
    super.key,
    required this.parentCategories,
    required this.childCategories,
    this.selectedParentId,
    this.selectedChildId,
    required this.onParentSelected,
    this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: parentCategories.map((cat) {
            final isSelected = cat.id == selectedParentId;
            return GestureDetector(
              onTap: () => onParentSelected(cat.id!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${cat.icon} ${cat.name}',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.green : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (childCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: childCategories.map((cat) {
              final isSelected = cat.id == selectedChildId;
              return GestureDetector(
                onTap: () => onChildSelected?.call(cat.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
