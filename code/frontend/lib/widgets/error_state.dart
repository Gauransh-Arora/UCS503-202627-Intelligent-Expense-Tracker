import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import 'primary_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message = 'Unable to complete request. Please try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                  width: AppTokens.cardBorderWidth,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1020352A),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.alertCircle,
                  color: AppColors.expense,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: SecondaryButton(
                  label: 'Try Again',
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
