import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';

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

    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      avatar: showEmoji
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            )
          : null,
      label: Text(category),
      labelStyle: TextStyle(
        fontFamily: AppTheme.fontSans,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(
        color: isSelected ? AppColors.buttonDepth : AppColors.border,
        width: AppTokens.cardBorderWidth,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
