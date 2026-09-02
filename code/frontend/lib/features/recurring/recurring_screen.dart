import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/wishlist_model.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recurring = MockData.recurringExpenses;
    final totalMonthly = recurring.fold<double>(0, (s, r) => s + r.amount);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🔄', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Recurring',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      formatter.format(totalMonthly),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${recurring.length} subscriptions & bills',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Upcoming Payments',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),

          ...recurring.map((r) => _RecurringCard(expense: r)),
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringExpenseModel expense;
  const _RecurringCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColor(expense.category);
    final daysUntil = expense.nextExpected.difference(DateTime.now()).inDays;

    Color urgencyColor;
    if (daysUntil <= 3) {
      urgencyColor = AppColors.danger;
    } else if (daysUntil <= 7) {
      urgencyColor = AppColors.warning;
    } else {
      urgencyColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(expense.emoji ?? '💳',
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.merchant,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.category,
                        style: TextStyle(
                            fontSize: 11,
                            color: catColor,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: urgencyColor),
                    const SizedBox(width: 4),
                    Text(
                      'Next: ${expense.nextExpectedFormatted}',
                      style: TextStyle(
                        fontSize: 12,
                        color: urgencyColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' ($daysUntil days)',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                expense.formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                expense.formattedInterval,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
