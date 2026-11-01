import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';

/// Shows an interactive modal dialog to edit the user's monthly income.
Future<double?> showEditIncomeDialog(
  BuildContext context, {
  required double currentIncome,
  VoidCallback? onSuccess,
}) async {
  final controller = TextEditingController(
    text: currentIncome > 0 ? currentIncome.toStringAsFixed(0) : '60000',
  );
  bool isSaving = false;
  String? errorMessage;

  return showDialog<double>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Monthly Income',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your monthly take-home income. Your remaining balance and monthly budget progress will automatically calibrate to this amount.',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  hintText: 'e.g. 75000',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  errorText: errorMessage,
                ),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final raw = controller.text.trim().replaceAll(',', '');
                      final val = double.tryParse(raw);
                      if (val == null || val < 0) {
                        setDialogState(() {
                          errorMessage = 'Please enter a valid amount (≥ 0)';
                        });
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ApiService.updateProfile(monthlyIncome: val);
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx, val);
                        onSuccess?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Monthly income updated to ₹${NumberFormat.decimalPattern('en_IN').format(val)}',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!dialogCtx.mounted) return;
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = 'Failed to save: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
