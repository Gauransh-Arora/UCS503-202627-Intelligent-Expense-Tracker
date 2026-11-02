import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/amount_display.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/edit_income_dialog.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../ask_expenses/ask_expenses_screen.dart';
import '../analytics/analytics_screen.dart';
import '../notifications/notifications_screen.dart';
import '../add_expense/add_expense_modal.dart';
import '../split_expense/shared_expenses_screen.dart';
import '../../services/api_service.dart';
import '../../services/local_notification_service.dart';
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
    ApiService.refreshNotifier.addListener(_onRefreshNotified);
  }

  void _onRefreshNotified() {
    if (mounted) {
      setState(() {
        _loadDashboardData();
      });
    }
  }

  @override
  void dispose() {
    ApiService.refreshNotifier.removeListener(_onRefreshNotified);
    super.dispose();
  }

  void _loadDashboardData({bool forceRefresh = false}) {
    _dashboardDataFuture = Future.wait([
      ApiService.getAnalyticsSummary(forceRefresh: forceRefresh),
      ApiService.getTransactions(limit: 5, forceRefresh: forceRefresh),
      ApiService.getCurrentUser(forceRefresh: forceRefresh)
          .catchError((_) => const UserModel(id: '', name: 'User', email: '')),
      ApiService.detectUnusualSpending(forceRefresh: forceRefresh)
          .catchError((_) => <String>[]),
    ]);
    ApiService.getUnreadNotificationCount(forceRefresh: forceRefresh)
        .then((count) {
          if (mounted) setState(() => _unreadCount = count);
        })
        .catchError((_) {});

    // Check for mid-month / 25th wishlist affordability and other auto-alerts
    ApiService.triggerAutoNotifications(forceRefresh: forceRefresh)
        .then((result) {
          if (result.notifications.isNotEmpty) {
            LocalNotificationService.showFromNotificationItems(
              result.notifications,
            );
            if (mounted) {
              setState(() {
                _unreadCount += result.generatedCount;
              });
            }
          }
        })
        .catchError((_) {});
  }

  /// Strips emojis from backend-provided strings at display time.
  static String stripEmoji(String input) {
    return input
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final currMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() {
            _loadDashboardData(forceRefresh: true);
          });
          await _dashboardDataFuture;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.expenseLight,
                          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(
                            color: AppColors.expense.withValues(alpha: 0.3),
                            width: AppTokens.cardBorderWidth,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.wifiOff,
                          size: 24,
                          color: AppColors.expense,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Unable to reach server',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}'.replaceAll('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: () => setState(() => _loadDashboardData()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, AppTokens.buttonHeight),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.borderStrong,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final summary = snapshot.data?[0] as AnalyticsSummary?;
            final recentExpenses =
                snapshot.data?[1] as List<ExpenseModel>? ?? [];
            final user =
                snapshot.data?[2] as UserModel? ??
                const UserModel(id: '', name: 'User', email: '');
            final anomalies = snapshot.data?[3] as List<dynamic>? ?? [];

            if (summary == null) {
              return const Center(
                child: Text(
                  'No financial data available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            final firstName = user.name.trim().isNotEmpty
                ? user.name.trim().split(' ').first
                : 'User';

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ─── Friendly Top App Bar ─────────────────────────────────────
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Row(
                    children: [
                      const AppLogo(size: 34, borderRadius: AppTokens.radiusSmall),
                      const SizedBox(width: 10),
                      // User Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hello, $firstName',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              currMonth,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Gamified Monthly Activity / Streak Badge
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                        border: Border.all(
                          color: AppColors.primaryMain.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.flame,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontSans,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Ask Expenses / Query
                    IconButton(
                      tooltip: 'Ask Expenses',
                      icon: const Icon(
                        LucideIcons.messageSquare,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AskExpensesScreen(),
                        ),
                      ),
                    ),

                    // Notification bell
                    IconButton(
                      tooltip: 'Notifications',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            LucideIcons.bell,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          if (_unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.expense,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            )
                            .then((_) {
                              ApiService.getUnreadNotificationCount()
                                  .then((count) {
                                    if (mounted) setState(() => _unreadCount = count);
                                  })
                                  .catchError((_) {});
                            });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Hero Financial Overview (Dark Green Treatment) ─────
                        _HeroFinancialCard(summary: summary),
                        const SizedBox(height: 16),

                        // ─── Gamified Budget & Progress Card ─────────────────────
                        _GamifiedBudgetCard(summary: summary),
                        const SizedBox(height: 18),

                        // ─── Quick Feature Shortcuts ─────────────────────────────
                        _QuickFeatureShortcuts(),
                        const SizedBox(height: 20),

                        // ─── Spending Alerts (if any) ────────────────────────────
                        _SpendingAlertRow(
                          anomalies: anomalies,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AskExpensesScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Category Breakdown ──────────────────────────────────
                        if (summary.byCategory.isNotEmpty) ...[
                          SectionHeader(
                            title: 'Category Breakdown',
                            actionLabel: 'Details',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AnalyticsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLarge,
                              ),
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
                              children: summary.byCategory.take(4).map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: _PlayfulCategoryRow(category: cat),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ─── Recent Transactions (Approachable Ledger) ───────────
                        SectionHeader(
                          title: 'Recent Transactions',
                          actionLabel: 'View all',
                          onAction: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const ExpensesScreen(),
                                ),
                              )
                              .then((_) => _loadDashboardData()),
                        ),
                        const SizedBox(height: 12),
                        if (recentExpenses.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLarge,
                              ),
                              border: Border.all(
                                color: AppColors.border,
                                width: AppTokens.cardBorderWidth,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  LucideIcons.receipt,
                                  size: 32,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No transactions recorded yet',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSans,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap the central + button to log your first spend.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSans,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...recentExpenses.map(
                            (expense) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: ExpenseCard(
                                expense: expense,
                                onTap: () => Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => ExpenseDetailScreen(
                                          expense: expense,
                                        ),
                                      ),
                                    )
                                    .then((_) => _loadDashboardData()),
                              ),
                            ),
                          ),
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

// ─── Hero Financial Overview (Dark Forest Green Treatment) ────────────────────

class _HeroFinancialCard extends StatelessWidget {
  final AnalyticsSummary summary;
  const _HeroFinancialCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final netBalance = summary.income - summary.totalSpending;
    final isPositive = netBalance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(
          color: AppColors.buttonDepth,
          width: AppTokens.cardBorderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.buttonDepth,
            offset: Offset(0, 4),
            blurRadius: 0,
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
                'TOTAL REMAINING',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  color: AppColors.mint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive ? AppColors.primaryMain : AppColors.expense,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: Text(
                  isPositive ? 'Savings Healthy' : 'Over Limit',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hero Balance Amount
          Text(
            currencyFormatter.format(netBalance),
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),

          // Split Breakdown Pills
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    onTap: () => showEditIncomeDialog(
                      context,
                      currentIncome: summary.income,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMain,
                              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                            ),
                            child: const Icon(
                              LucideIcons.arrowDownLeft,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontSans,
                                        fontSize: 10,
                                        color: AppColors.mint,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      LucideIcons.pencil,
                                      size: 9,
                                      color: AppColors.mint,
                                    ),
                                  ],
                                ),
                                Text(
                                  currencyFormatter.format(summary.income),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontSans,
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.expense,
                          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                        ),
                        child: const Icon(
                          LucideIcons.arrowUpRight,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spent',
                              style: TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 10,
                                color: AppColors.mint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              currencyFormatter.format(summary.totalSpending),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Gamified Budget & Progress Card ──────────────────────────────────────────

class _GamifiedBudgetCard extends StatelessWidget {
  final AnalyticsSummary summary;
  const _GamifiedBudgetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final income = summary.income > 0 ? summary.income : 1.0;
    final spentRatio = (summary.totalSpending / income).clamp(0.0, 1.0);
    final spentPct = (summary.totalSpending / income * 100).round();
    final remaining = (summary.income - summary.totalSpending).clamp(0.0, double.infinity);

    Color progressColor = AppColors.primaryMain;
    String feedbackMessage = "Great pacing! You're 70% through your monthly budget.";

    if (spentPct < 50) {
      progressColor = AppColors.primaryMain;
      feedbackMessage = "Pacing smoothly! You have ${currencyFormatter.format(remaining)} remaining this month.";
    } else if (spentPct <= 85) {
      progressColor = AppColors.primaryBright;
      feedbackMessage = "You're $spentPct% through your monthly income. On track!";
    } else {
      progressColor = AppColors.warning;
      feedbackMessage = "Heads up: You've used $spentPct% of your monthly income.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.target,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Monthly Budget Goal',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '$spentPct% Used',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chunky Progress Bar
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: spentRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Encouraging Contextual Feedback Message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 14,
                color: AppColors.primaryMain,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feedbackMessage,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Feature Shortcuts (Duolingo Tactile Tiles) ─────────────────────────

class _QuickFeatureShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionTile(
          icon: LucideIcons.scanLine,
          label: 'Scan Bill',
          onTap: () {
            AddExpenseModal.show(context);
          },
        ),
        const SizedBox(width: 10),
        _QuickActionTile(
          icon: LucideIcons.trendingUp,
          label: 'Trends',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            );
          },
        ),
        const SizedBox(width: 10),
        _QuickActionTile(
          icon: LucideIcons.users,
          label: 'Shared',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SharedExpensesScreen()),
            );
          },
        ),
        const SizedBox(width: 10),
        _QuickActionTile(
          icon: LucideIcons.messageSquare,
          label: 'Ask AI',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AskExpensesScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Compact Structured Alert Row ─────────────────────────────────────────────

class _SpendingAlertRow extends StatelessWidget {
  final List<dynamic> anomalies;
  final VoidCallback onTap;
  const _SpendingAlertRow({required this.anomalies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAnomaly = anomalies.isNotEmpty;
    final title = hasAnomaly
        ? 'Unusual spending detected'
        : 'Spending within normal range';
    final rawSubtitle = hasAnomaly && anomalies.first.toString().isNotEmpty
        ? anomalies.first.toString()
        : 'All categories remain within typical parameters for this billing cycle.';
    final cleanSubtitle = _HomeScreenState.stripEmoji(rawSubtitle);

    final iconColor = hasAnomaly ? AppColors.warning : AppColors.primaryMain;
    final bgColor = hasAnomaly ? AppColors.warningLight : AppColors.surfaceCard;
    final borderColor = hasAnomaly
        ? AppColors.warning.withValues(alpha: 0.4)
        : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(
            color: borderColor,
            width: AppTokens.cardBorderWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C20352A),
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              hasAnomaly ? LucideIcons.alertTriangle : LucideIcons.checkCircle2,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Playful Category Row ─────────────────────────────────────────────────────

class _PlayfulCategoryRow extends StatelessWidget {
  final CategorySpending category;
  const _PlayfulCategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category.category);
    final ratio = (category.percentage / 100).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.category,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${category.percentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            AmountDisplay(
              amount: category.amount,
              style: AmountDisplayStyle.small,
              textAlign: TextAlign.end,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.sage,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
