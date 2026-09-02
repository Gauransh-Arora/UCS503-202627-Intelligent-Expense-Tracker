import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final bool showEmoji;

  const CategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onSelected,
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category);
    final emoji = AppColors.categoryEmoji(category);

    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,
      avatar: showEmoji
          ? Text(emoji, style: const TextStyle(fontSize: 14))
          : null,
      label: Text(category),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selectedColor: color,
      backgroundColor: AppColors.surfaceElevated,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : AppColors.border,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
