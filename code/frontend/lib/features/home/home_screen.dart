import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/section_header.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../ask_expenses/ask_expenses_screen.dart';
import '../analytics/analytics_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/api_service.dart';
import '../../models/expense_model.dart';
import '../../models/analytics_model.dart';
import '../../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _dashboardDataFuture;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    _dashboardDataFuture = Future.wait([
      ApiService.getAnalyticsSummary(),
      ApiService.getTransactions(limit: 5),
      ApiService.getCurrentUser().catchError((_) => const UserModel(
            id: '',
            name: 'User',
            email: '',
          )),
      ApiService.detectUnusualSpending().catchError((_) => <String>[]),
    ]);
    ApiService.getUnreadNotificationCount().then((count) {
      if (mounted) setState(() => _unreadCount = count);
    }).catchError((_) {});
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final currMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadDashboardData();
          });
          await _dashboardDataFuture;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('Unable to connect to server', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}'.replaceAll('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _loadDashboardData()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final summary = snapshot.data?[0] as AnalyticsSummary?;
            final recentExpenses = snapshot.data?[1] as List<ExpenseModel>? ?? [];
            final user = snapshot.data?[2] as UserModel? ?? const UserModel(id: '', name: 'User', email: '');
            final anomalies = snapshot.data?[3] as List<dynamic>? ?? [];

            if (summary == null) {
              return const Center(child: Text("No data"));
            }

            final firstName = user.name.trim().isNotEmpty
                ? user.name.trim().split(' ').first
                : 'there';

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()}, $firstName',
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
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
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
                          if (_unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ).then((_) {
                          ApiService.getUnreadNotificationCount().then((count) {
                            if (mounted) setState(() => _unreadCount = count);
                          }).catchError((_) {});
                        });
                      },
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
                          anomalies: anomalies,
                          onAskTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AskExpensesScreen()),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Category spending bars ─────────────────────────────
                        if (summary.byCategory.isNotEmpty) ...[
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
                        ],

                        // ─── Recent Expenses ────────────────────────────────────
                        SectionHeader(
                          title: 'Recent Expenses',
                          actionLabel: 'View All',
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                          ).then((_) => _loadDashboardData()),
                        ),
                        const SizedBox(height: 16),
                        if (recentExpenses.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textTertiary),
                                const SizedBox(height: 10),
                                Text(
                                  'No expenses recorded yet',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scan a receipt or add an expense to see it here.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          )
                        else
                          ...recentExpenses.map((expense) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ExpenseCard(
                                  expense: expense,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ExpenseDetailScreen(expense: expense),
                                    ),
                                  ).then((_) => _loadDashboardData()),
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
    final monthName = DateFormat('MMMM').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryDark,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName Spending',
                style: const TextStyle(
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
  final List<dynamic> anomalies;
  final VoidCallback onAskTap;
  const _InsightCard({required this.anomalies, required this.onAskTap});

  @override
  Widget build(BuildContext context) {
    final hasAnomaly = anomalies.isNotEmpty;
    final title = hasAnomaly ? 'Spending Alert' : 'Spending on Track';
    final subtitle = hasAnomaly && anomalies.first.toString().isNotEmpty
        ? anomalies.first.toString()
        : 'All category expenses are within your usual historical range this month.';
    final cardColor = hasAnomaly ? AppColors.warningLight : AppColors.primaryLight;
    final borderColor = hasAnomaly ? AppColors.warning : AppColors.primary;
    final iconData = hasAnomaly ? Icons.warning_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(iconData, size: 22, color: borderColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: borderColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
                color: borderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: borderColor,
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
    final icon = AppColors.categoryIcon(category.category);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
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
