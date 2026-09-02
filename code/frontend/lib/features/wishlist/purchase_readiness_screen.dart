import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/wishlist_model.dart';
import '../../widgets/primary_button.dart';

class PurchaseReadinessScreen extends StatelessWidget {
  final WishlistItemModel item;

  const PurchaseReadinessScreen({super.key, required this.item});

  Color get _verdictColor {
    switch (item.readiness) {
      case AppConstants.readinessComfortable:
        return AppColors.success;
      case AppConstants.readinessPossible:
        return AppColors.warning;
      case AppConstants.readinessNotRecommended:
      default:
        return AppColors.danger;
    }
  }

  String get _verdictBadge {
    switch (item.readiness) {
      case AppConstants.readinessComfortable:
        return '🟢 Comfortable';
      case AppConstants.readinessPossible:
        return '🟡 Possible';
      case AppConstants.readinessNotRecommended:
      default:
        return '🔴 Not Recommended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = MockData.analyticsSummary;
    final recurringTotal = MockData.recurringExpenses.fold<double>(
      0,
      (sum, r) => sum + r.amount,
    );
    final monthlySavings = summary.remaining;
    final monthsToSave = (item.expectedPrice / (monthlySavings > 0 ? monthlySavings : 1)).ceil();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Readiness'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Top Item Overview Card ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _verdictColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      item.imageEmoji ?? '🛍️',
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  item.formattedPrice,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _verdictColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _verdictColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    _verdictBadge,
                    style: TextStyle(
                      color: _verdictColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Financial Health Context ────────────────────────────
          Text(
            'Financial Overview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _FinancialRow(
                  label: 'Monthly Income',
                  value: summary.formattedIncome,
                  color: AppColors.success,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const Divider(height: 20),
                _FinancialRow(
                  label: 'Current Month Spending',
                  value: summary.formattedTotal,
                  color: AppColors.textPrimary,
                  icon: Icons.shopping_bag_outlined,
                ),
                const Divider(height: 20),
                _FinancialRow(
                  label: 'Recurring Commitments',
                  value: '₹${recurringTotal.toStringAsFixed(0)} / mo',
                  color: AppColors.info,
                  icon: Icons.repeat_rounded,
                ),
                const Divider(height: 20),
                _FinancialRow(
                  label: 'Estimated Discretionary Buffer',
                  value: summary.formattedRemaining,
                  color: AppColors.accent,
                  icon: Icons.savings_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── AI Readiness Assessment ─────────────────────────────
          Text(
            'AI Readiness Assessment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _verdictColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _verdictColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: _verdictColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Verdict: ${item.readiness}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _verdictColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.analysis ??
                      'Based on your income, spending trends, and recurring obligations, this item represents a financial commitment that requires careful budgeting.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          monthsToSave <= 1
                              ? 'Affordable within 1 month of standard savings buffer.'
                              : 'Recommended savings duration: ~$monthsToSave months at current pace.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Action Buttons ──────────────────────────────────────
          PrimaryButton(
            label: 'Set Up Savings Goal',
            icon: const Icon(Icons.flag_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Savings goal created for ${item.name}!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Mark as Purchased',
            icon: const Icon(Icons.check_circle_outline, color: AppColors.accent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} marked as purchased!'),
                  backgroundColor: AppColors.accent,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _FinancialRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
