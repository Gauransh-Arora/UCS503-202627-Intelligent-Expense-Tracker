import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/intelligence_model.dart';
import '../../services/api_service.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<SubscriptionResponseModel> _subscriptions = [];
  List<DetectedRecurringModel> _recurringBills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadIntelligenceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIntelligenceData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.detectSubscriptions(forceRefresh: forceRefresh),
        ApiService.detectRecurringExpenses(forceRefresh: forceRefresh),
      ]);

      if (!mounted) return;
      setState(() {
        _subscriptions = results[0] as List<SubscriptionResponseModel>;
        _recurringBills = results[1] as List<DetectedRecurringModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalMonthlySubscriptions =>
      _subscriptions.fold(0.0, (sum, item) => sum + item.monthlyAmount);

  double get _totalMonthlyBills =>
      _recurringBills.fold(0.0, (sum, item) => sum + item.amount);

  double get _totalMonthly => _totalMonthlySubscriptions > 0
      ? _totalMonthlySubscriptions
      : _totalMonthlyBills;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recurring & Subscriptions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          tabs: [
            Tab(text: 'Subscriptions (${_subscriptions.length})'),
            Tab(text: 'Recurring Bills (${_recurringBills.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadIntelligenceData(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // Overview Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: Icon(
                              Icons.repeat_rounded,
                              size: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Monthly Recurring',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormatter.format(_totalMonthly),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_subscriptions.length + _recurringBills.length} active recurring commitments',
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Content
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Subscriptions Tab
                        _subscriptions.isEmpty
                            ? _buildEmptyTab(
                                'No recurring subscriptions detected.',
                              )
                            : ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _subscriptions.length,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final sub = _subscriptions[index];
                                  return _buildSubscriptionCard(sub);
                                },
                              ),

                        // Recurring Bills Tab
                        _recurringBills.isEmpty
                            ? _buildEmptyTab('No recurring bills detected.')
                            : ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recurringBills.length,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final bill = _recurringBills[index];
                                  return _buildRecurringCard(bill);
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionResponseModel sub) {
    final cat = sub.categoryName ?? 'Subscriptions';
    final catColor = AppColors.categoryColor(cat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                AppColors.categoryIcon(cat),
                size: 20,
                color: catColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.merchantName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(sub.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
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
                sub.formattedMonthlyAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${sub.formattedAnnualAmount} / yr',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCard(DetectedRecurringModel bill) {
    final cat = bill.category ?? 'Bills';
    final catColor = AppColors.categoryColor(cat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                AppColors.categoryIcon(cat),
                size: 20,
                color: catColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.merchantName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (bill.nextExpected != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${DateFormat('dd MMM').format(bill.nextExpected!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bill.formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '/${bill.frequency}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.repeat_rounded,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
