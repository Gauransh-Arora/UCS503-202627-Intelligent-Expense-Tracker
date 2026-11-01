
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/analytics_model.dart';
import '../../services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;
  List<String> _unusualAlerts = [];
  SpendingSummaryResponse? _spendingSummary;
  MonthlyComparison? _monthlyComparison;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.detectUnusualSpending(forceRefresh: forceRefresh)
            .catchError((_) => <String>[]),
        ApiService.generateSpendingSummary(forceRefresh: forceRefresh)
            .then<SpendingSummaryResponse?>((v) => v)
            .catchError((_) => null),
        ApiService.compareMonthlySpending(forceRefresh: forceRefresh)
            .then<MonthlyComparison?>((v) => v)
            .catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        _unusualAlerts = results[0] as List<String>;
        _spendingSummary = results[1] as SpendingSummaryResponse?;
        _monthlyComparison = results[2] as MonthlyComparison?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _cleanText(String input) {
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Financial Insights')),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadInsights(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // ─── Spending Summary Card ──────────────────────────────
                  if (_spendingSummary != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.radiusSmall,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Spending Analysis',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _cleanText(_spendingSummary!.summaryText),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total: ${currencyFormatter.format(_spendingSummary!.totalSpent)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (_spendingSummary!.topCategory != null)
                                Text(
                                  'Top: ${_spendingSummary!.topCategory}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ─── Month-over-Month Comparison Card ───────────────────────
                  if (_monthlyComparison != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly Comparison',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _monthlyComparison!.percentageChange > 0
                                      ? AppColors.dangerLight
                                      : AppColors.successLight,
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.radiusSmall,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _monthlyComparison!.percentageChange > 0
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      size: 13,
                                      color:
                                          _monthlyComparison!.percentageChange >
                                              0
                                          ? AppColors.danger
                                          : AppColors.success,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${_monthlyComparison!.percentageChange.abs().toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color:
                                            _monthlyComparison!
                                                    .percentageChange >
                                                0
                                            ? AppColors.danger
                                            : AppColors.success,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _cleanText(_monthlyComparison!.verdict),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _monthlyComparison!.currentMonth,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormatter.format(
                                      _monthlyComparison!.currentTotal,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _monthlyComparison!.previousMonth,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormatter.format(
                                      _monthlyComparison!.previousTotal,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─── Unusual Spending Alerts Section ────────────────────────
                  Text(
                    'Unusual Spending & Anomalies',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_unusualAlerts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.success,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Normal Spending Patterns',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'No unusual spikes or anomaly expenses detected for this period.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._unusualAlerts.map(
                      (alert) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMedium,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Anomaly Alert',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _cleanText(alert),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
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
            ),
    );
  }
}
