import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/expense_model.dart';
import '../../services/api_service.dart';
import '../../widgets/amount_display.dart';
import '../../widgets/primary_button.dart';
import '../split_expense/split_screen.dart';
import '../add_expense/manual_expense_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final ExpenseModel expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case "upi":
        return "UPI";
      case "credit_card":
        return "Credit Card";
      case "debit_card":
        return "Debit Card";
      case "net_banking":
        return "Net Banking";
      case "cash":
        return "Cash";
      default:
        return method.isNotEmpty ? method[0].toUpperCase() + method.substring(1) : method;
    }
  }

  String _sourceLabel(String? source) {
    switch (source) {
      case 'ocr_receipt':
        return 'Scanned Receipt';
      case 'ocr_upi':
        return 'UPI Screenshot';
      case 'bank_statement':
        return 'Bank Statement';
      default:
        return 'Manual Entry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColor(expense.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            tooltip: 'Edit transaction',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => Navigator.of(context)
                .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ManualExpenseScreen(editExpense: expense),
                  ),
                )
                .then((res) {
                  if (res == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                }),
          ),
          IconButton(
            tooltip: 'Delete transaction',
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.debit,
              size: 20,
            ),
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: Typographic Ledger Statement ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSmall,
                          ),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppColors.categoryIcon(expense.category),
                              size: 13,
                              color: catColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              expense.category,
                              style: TextStyle(
                                fontFamily: AppTheme.fontSans,
                                color: catColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        expense.formattedDate,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    expense.merchant,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  AmountDisplay(
                    amount: expense.amount,
                    style: AmountDisplayStyle.large,
                    isExpense: true,
                    showSign: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Details Table ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: [
                  _LedgerDetailRow(
                    label: 'Payment Method',
                    value: _formatPaymentMethod(expense.paymentMethod),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _LedgerDetailRow(
                    label: 'Source',
                    value: _sourceLabel(expense.source),
                  ),
                  if (expense.isRecurring) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    const _LedgerDetailRow(
                      label: 'Frequency',
                      value: 'Recurring Schedule',
                    ),
                  ],
                  if (expense.notes != null &&
                      expense.notes!.trim().isNotEmpty) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _LedgerDetailRow(label: 'Notes', value: expense.notes!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Items Table ──────────────────────────────────────────────────
            if (expense.items.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ITEMIZED BREAKDOWN',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...expense.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.quantity > 1
                                    ? '${item.name} (×${item.quantity})'
                                    : item.name,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            AmountDisplay(
                              amount: item.total,
                              style: AmountDisplayStyle.small,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total itemized',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AmountDisplay(
                          amount: expense.amount,
                          style: AmountDisplayStyle.small,
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── Actions ──────────────────────────────────────────────────────
            PrimaryButton(
              label: 'Split with contacts',
              icon: const Icon(
                Icons.people_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SplitScreen(expense: expense),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Delete transaction',
          style: TextStyle(
            fontFamily: AppTheme.fontSans,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove "${expense.merchant}" for ${expense.formattedAmount} from the ledger? This action cannot be undone.',
          style: const TextStyle(
            fontFamily: AppTheme.fontSans,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.deleteTransaction(expense.id);
                if (context.mounted) {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context, true); // screen
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Delete failed: ${e.toString().replaceAll('Exception: ', '')}',
                      ),
                      backgroundColor: AppColors.debit,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.debit,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _LedgerDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _LedgerDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
