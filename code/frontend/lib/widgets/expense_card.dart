import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../models/expense_model.dart';
import 'amount_display.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final bool showDate;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.showDate = false,
  });

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'credit_card':
        return 'Card';
      case 'debit_card':
        return 'Debit';
      case 'net_banking':
        return 'Net Banking';
      case 'cash':
        return 'Cash';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColor(expense.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category icon with colored accent pip
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          AppColors.categoryIcon(expense.category),
                          size: 22,
                          color: catColor,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Merchant + secondary line
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expense.merchant,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              expense.category,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '·',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCream,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                            ),
                            child: Text(
                              showDate
                                  ? expense.formattedDate
                                  : _formatPaymentMethod(expense.paymentMethod),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (expense.isRecurring) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                              ),
                              child: const Text(
                                'Recurring',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Amount
                AmountDisplay(
                  amount: expense.amount,
                  style: AmountDisplayStyle.medium,
                  isExpense: true,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
