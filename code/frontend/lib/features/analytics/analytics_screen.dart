import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../models/analytics_model.dart';
import '../../widgets/section_header.dart';
import '../insights/insights_screen.dart';
import '../recurring/recurring_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _touchedIndex = -1;
  late DateTime _selectedMonth;
  late Future<AnalyticsSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _summaryFuture = ApiService.getAnalyticsSummary(
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );
    ApiService.refreshNotifier.addListener(_onRefreshNotified);
  }

  void _onRefreshNotified() {
    if (mounted) {
      setState(() {
        _summaryFuture = ApiService.getAnalyticsSummary(
          month: _selectedMonth.month,
          year: _selectedMonth.year,
        );
      });
    }
  }

  @override
  void dispose() {
    ApiService.refreshNotifier.removeListener(_onRefreshNotified);
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  void _selectMonth(DateTime month) {
    if (_selectedMonth.year == month.year &&
        _selectedMonth.month == month.month) {
      return;
    }
    setState(() {
      _selectedMonth = month;
      _touchedIndex = -1;
      _summaryFuture = ApiService.getAnalyticsSummary(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    });
  }

  void _previousMonth() {
    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1));
  }

  void _showMonthPickerSheet() {
    final now = DateTime.now();
    final months = List.generate(24, (index) {
      return DateTime(now.year, now.month - index, 1);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Month',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (ctx, index) {
                    final monthDate = months[index];
                    final isSelected =
                        monthDate.year == _selectedMonth.year &&
                        monthDate.month == _selectedMonth.month;
                    final isCurrent =
                        monthDate.year == now.year &&
                        monthDate.month == now.month;

                    return ListTile(
                      title: Text(
                        DateFormat('MMMM yyyy').format(monthDate),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _selectMonth(monthDate);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                tooltip: 'Previous month',
                onPressed: _previousMonth,
              ),
              InkWell(
                onTap: _showMonthPickerSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM yyyy').format(_selectedMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: _isCurrentMonth
                      ? AppColors.textSecondary.withOpacity(0.3)
                      : null,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                tooltip: 'Next month',
                onPressed: _isCurrentMonth ? null : _nextMonth,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: FutureBuilder<AnalyticsSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.danger),
              ),
            );
          }
          final summary = snapshot.data;
          if (summary == null) return const Center(child: Text('No data'));

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _summaryFuture = ApiService.getAnalyticsSummary(
                  month: _selectedMonth.month,
                  year: _selectedMonth.year,
                  forceRefresh: true,
                );
              });
              await _summaryFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: [
                // ─── Total + MoM ────────────────────────────────────────────────
                _TotalCard(summary: summary, selectedMonth: _selectedMonth),
                const SizedBox(height: 24),

                // ─── Quick actions ───────────────────────────────────────────────
                Row(
                  children: [
                    _QuickCard(
                      icon: Icons.warning_rounded,
                      label: 'Unusual\nSpending',
                      color: AppColors.warning,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InsightsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _QuickCard(
                      icon: Icons.autorenew_rounded,
                      label: 'Recurring\nExpenses',
                      color: AppColors.info,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecurringScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Donut chart ─────────────────────────────────────────────────
                const SectionHeader(title: 'Spending by Category'),
                const SizedBox(height: 16),
                if (summary.byCategory.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: const Text(
                      'No category spending recorded for this month.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else ...[
                  _DonutChart(
                    categories: summary.byCategory,
                    touchedIndex: _touchedIndex,
                    onTouch: (i) => setState(() => _touchedIndex = i),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  ...summary.byCategory.map(
                    (cat) => _CategoryLegendRow(
                      category: cat,
                      isSelected:
                          summary.byCategory.indexOf(cat) == _touchedIndex,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ─── Line chart ──────────────────────────────────────────────────
                const SectionHeader(title: 'Monthly Trend'),
                const SizedBox(height: 16),
                _LineChart(data: summary.monthlyTrend),
                const SizedBox(height: 24),

                // ─── Top merchants ───────────────────────────────────────────────
                const SectionHeader(title: 'Top Merchants'),
                const SizedBox(height: 16),
                if (summary.topMerchants.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: const Text(
                      'No merchant data recorded for this month.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...summary.topMerchants.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    return _MerchantRow(rank: i + 1, merchant: m);
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Total Card ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final AnalyticsSummary summary;
  final DateTime selectedMonth;

  const _TotalCard({required this.summary, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final pct = summary.monthOverMonthChange.abs().toStringAsFixed(1);
    final isUp = summary.isSpendingUp;
    final prevMonth = DateFormat('MMM')
        .format(DateTime(selectedMonth.year, selectedMonth.month - 1));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spending',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                summary.formattedTotal,
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isUp ? AppColors.dangerLight : AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14,
                      color: isUp ? AppColors.danger : AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pct% vs $prevMonth',
                      style: TextStyle(
                        color: isUp ? AppColors.danger : AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Card ───────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Donut Chart ──────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final List<CategorySpending> categories;
  final int touchedIndex;
  final void Function(int) onTouch;

  const _DonutChart({
    required this.categories,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (response != null &&
                  response.touchedSection != null &&
                  event is FlTapUpEvent) {
                onTouch(response.touchedSection!.touchedSectionIndex);
              }
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 3,
          centerSpaceRadius: 60,
          sections: categories.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            final isTouched = i == touchedIndex;
            final color = AppColors.categoryColor(cat.category);

            return PieChartSectionData(
              color: color,
              value: cat.percentage,
              title: isTouched ? '${cat.percentage.toStringAsFixed(1)}%' : '',
              radius: isTouched ? 70 : 55,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  final CategorySpending category;
  final bool isSelected;

  const _CategoryLegendRow({required this.category, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category.category);
    final icon = AppColors.categoryIcon(category.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        vertical: 10,
        horizontal: isSelected ? 12 : 0,
      ),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              category.category,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${category.percentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            category.formattedAmount,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Line Chart ───────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<MonthlySpending> data;
  const _LineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: const Text(
          'No trend data available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final maxVal = data
        .map((d) => d.amount)
        .fold<double>(0.0, (a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.2 : 100.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (value != i.toDouble() || i < 0 || i >= data.length) {
                    return const SizedBox();
                  }
                  String label = data[i].month;
                  try {
                    final parts = label.split('-');
                    if (parts.length >= 2) {
                      final year = int.tryParse(parts[0]) ?? 2026;
                      final month = int.tryParse(parts[1]) ?? 1;
                      label = DateFormat('MMM').format(DateTime(year, month));
                    }
                  } catch (_) {}
                  return Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.amount);
              }).toList(),
              isCurved: true,
              color: AppColors.accent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  '₹${s.y.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Merchant Row ─────────────────────────────────────────────────────────────

class _MerchantRow extends StatelessWidget {
  final int rank;
  final dynamic merchant;

  const _MerchantRow({required this.rank, required this.merchant});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(merchant.category);
    final icon = AppColors.categoryIcon(merchant.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: rank <= 3
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.merchant,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${merchant.transactionCount} transactions',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            merchant.formattedAmount,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
