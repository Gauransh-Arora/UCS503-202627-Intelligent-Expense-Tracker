import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/split_model.dart';

class SharedExpensesScreen extends StatelessWidget {
  const SharedExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owe = MockData.debtsYouOwe;
    final owedToYou = MockData.debtsOwedToYou;

    final totalYouOwe = owe.fold<double>(0, (s, d) => s + d.amount);
    final totalOwedToYou = owedToYou.fold<double>(0, (s, d) => s + d.amount);
    final net = totalOwedToYou - totalYouOwe;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shared Expenses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Net balance card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: net >= 0 ? AppColors.successGradient : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  net >= 0 ? 'You are owed' : 'You owe',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${net.abs().toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  net >= 0
                      ? 'Overall you\'re in a good position!'
                      : 'Settle up to clear your debts',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // You owe section
          if (owe.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.arrow_upward_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 6),
                Text(
                  'You owe  (₹${totalYouOwe.toStringAsFixed(0)})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.danger,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...owe.map((debt) => _DebtCard(debt: debt, isOwedToYou: false)),
            const SizedBox(height: 24),
          ],

          // Owed to you
          if (owedToYou.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.arrow_downward_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Owed to you  (₹${totalOwedToYou.toStringAsFixed(0)})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...owedToYou.map((debt) => _DebtCard(debt: debt, isOwedToYou: true)),
          ],
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final bool isOwedToYou;

  const _DebtCard({required this.debt, required this.isOwedToYou});

  @override
  Widget build(BuildContext context) {
    final name = isOwedToYou ? debt.fromUser : debt.toUser;
    final initials = name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    final color = isOwedToYou ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  debt.expenseDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                debt.formattedAmount,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (!isOwedToYou)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reminder sent to $name!'),
                        backgroundColor: AppColors.accent,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Remind', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
