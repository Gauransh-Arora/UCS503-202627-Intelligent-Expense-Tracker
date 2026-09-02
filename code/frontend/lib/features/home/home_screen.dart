import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/section_header.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../ask_expenses/ask_expenses_screen.dart';
import '../analytics/analytics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final summary = MockData.analyticsSummary;
    final recentExpenses = MockData.expenses.take(3).toList();
    final currMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}, ${MockData.currentUser.name.split(' ')[0]} 👋',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      currMonth,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Spending Summary Card ──────────────────────────────
                  _SpendingSummaryCard(summary: summary),
                  const SizedBox(height: 24),

                  // ─── AI Insight ─────────────────────────────────────────
                  _InsightCard(
                    onAskTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AskExpensesScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Category spending bars ─────────────────────────────
                  SectionHeader(
                    title: 'Spending by Category',
                    actionLabel: 'Details',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...summary.byCategory.map((cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryBar(category: cat),
                      )),
                  const SizedBox(height: 24),

                  // ─── Recent Expenses ────────────────────────────────────
                  SectionHeader(
                    title: 'Recent Expenses',
                    actionLabel: 'View All',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...recentExpenses.map((expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ExpenseCard(
                          expense: expense,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailScreen(expense: expense),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spending Summary Card ─────────────────────────────────────────────────────

class _SpendingSummaryCard extends StatelessWidget {
  final dynamic summary;
  const _SpendingSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pctChange = summary.monthOverMonthChange.abs().toStringAsFixed(1);
    final isUp = summary.isSpendingUp;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'September Spending',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: isUp ? const Color(0xFFFFB3B3) : const Color(0xFF86EFAC),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pctChange%',
                      style: TextStyle(
                        color: isUp ? const Color(0xFFFFB3B3) : const Color(0xFF86EFAC),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary.formattedTotal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryMetric(
                label: 'Income',
                value: summary.formattedIncome,
                icon: Icons.arrow_downward_rounded,
                iconColor: const Color(0xFF86EFAC),
              ),
              const SizedBox(width: 24),
              _SummaryMetric(
                label: 'Expenses',
                value: summary.formattedTotal,
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFFFFB3B3),
              ),
              const SizedBox(width: 24),
              _SummaryMetric(
                label: 'Remaining',
                value: summary.formattedRemaining,
                icon: Icons.savings_outlined,
                iconColor: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Insight Card ──────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final VoidCallback onAskTap;
  const _InsightCard({required this.onAskTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('⚠️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Alert',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.warning,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your food spending is 18% higher than last month.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAskTap,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Bar ─────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final dynamic category;
  const _CategoryBar({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category.category);
    final emoji = AppColors.categoryEmoji(category.category);

    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.category,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              category.formattedAmount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: category.percentage / 100,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
