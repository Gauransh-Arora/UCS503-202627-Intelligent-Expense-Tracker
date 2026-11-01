import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import 'manual_expense_screen.dart';
import 'ocr_flow/capture_screen.dart';
import 'bank_statement_screen.dart';

enum AddExpenseOption {
  manual,
  receipt,
  upi,
  statement,
}

class AddExpenseModal extends StatelessWidget {
  const AddExpenseModal({super.key});

  /// Displays the modal bottom sheet and safely handles pushing the chosen screen
  /// after the modal dismisses, preventing Navigator assertion errors (`!_debugLocked`).
  static Future<void> show(BuildContext context) async {
    final nav = Navigator.of(context);
    final option = await showModalBottomSheet<AddExpenseOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseModal(),
    );

    if (option == null) return;

    switch (option) {
      case AddExpenseOption.manual:
        nav.push(
          MaterialPageRoute(builder: (_) => const ManualExpenseScreen()),
        );
        break;
      case AddExpenseOption.receipt:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const CaptureScreen(type: 'receipt'),
          ),
        );
        break;
      case AddExpenseOption.upi:
        nav.push(
          MaterialPageRoute(builder: (_) => const CaptureScreen(type: 'upi')),
        );
        break;
      case AddExpenseOption.statement:
        nav.push(
          MaterialPageRoute(builder: (_) => const BankStatementScreen()),
        );
        break;
    }
  }

  void _select(
    BuildContext context,
    AddExpenseOption option,
    Widget Function() screenBuilder,
  ) {
    Navigator.pop(context, option);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Record Expense',
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose how you want to log your transaction',
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              border: Border.all(
                color: AppColors.border,
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
            child: Column(
              children: [
                _ModalOptionTile(
                  icon: LucideIcons.fileEdit,
                  title: 'Manual entry',
                  subtitle: 'Type merchant, category, and amount',
                  onTap: () => _select(
                    context,
                    AddExpenseOption.manual,
                    () => const ManualExpenseScreen(),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _ModalOptionTile(
                  icon: LucideIcons.camera,
                  title: 'Scan receipt / bill',
                  subtitle: 'Extract items and total with camera or gallery',
                  onTap: () => _select(
                    context,
                    AddExpenseOption.receipt,
                    () => const CaptureScreen(type: 'receipt'),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _ModalOptionTile(
                  icon: LucideIcons.smartphone,
                  title: 'UPI screenshot',
                  subtitle: 'Extract payment ID, merchant, and total',
                  onTap: () => _select(
                    context,
                    AddExpenseOption.upi,
                    () => const CaptureScreen(type: 'upi'),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _ModalOptionTile(
                  icon: LucideIcons.fileSpreadsheet,
                  title: 'Import bank statement',
                  subtitle: 'Upload and parse PDF or CSV statements',
                  onTap: () => _select(
                    context,
                    AddExpenseOption.statement,
                    () => const BankStatementScreen(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModalOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
