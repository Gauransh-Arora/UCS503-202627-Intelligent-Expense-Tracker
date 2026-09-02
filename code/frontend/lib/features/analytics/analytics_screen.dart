import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = MockData.analyticsSummary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Row(
              children: [
                Text('Sep 2026'),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          // ─── Total + MoM ────────────────────────────────────────────────
          _TotalCard(summary: summary),
          const SizedBox(height: 24),

          // ─── Quick actions ───────────────────────────────────────────────
          Row(
            children: [
              _QuickCard(
                emoji: '⚠️',
                label: 'Unusual\nSpending',
                color: AppColors.warning,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                ),
              ),
              const SizedBox(width: 12),
              _QuickCard(
                emoji: '🔄',
                label: 'Recurring\nExpenses',
                color: AppColors.info,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Donut chart ─────────────────────────────────────────────────
          SectionHeader(title: 'Spending by Category'),
          const SizedBox(height: 16),
          _DonutChart(
            categories: summary.byCategory,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          const SizedBox(height: 16),
          // Legend
          ...summary.byCategory.map((cat) => _CategoryLegendRow(
                category: cat,
                isSelected: summary.byCategory.indexOf(cat) == _touchedIndex,
              )),
          const SizedBox(height: 24),

          // ─── Line chart ──────────────────────────────────────────────────
          SectionHeader(title: 'Monthly Trend'),
          const SizedBox(height: 16),
          _LineChart(data: summary.monthlyTrend),
          const SizedBox(height: 24),

          // ─── Top merchants ───────────────────────────────────────────────
          SectionHeader(title: 'Top Merchants'),
          const SizedBox(height: 16),
          ...summary.topMerchants.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return _MerchantRow(rank: i + 1, merchant: m);
          }),
        ],
      ),
    );
  }
}

// ─── Total Card ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final AnalyticsSummary summary;
  const _TotalCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = summary.monthOverMonthChange.abs().toStringAsFixed(1);
    final isUp = summary.isSpendingUp;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Spending',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                  )),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                summary.formattedTotal,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isUp
                      ? AppColors.dangerLight
                      : AppColors.successLight,
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
                      '$pct% vs Aug',
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
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.emoji,
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
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
    final emoji = AppColors.categoryEmoji(category.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: isSelected ? 12 : 0),
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
          Text(emoji),
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
    final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();
                  return Text(
                    data[i].month,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
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
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
    final emoji = AppColors.categoryEmoji(merchant.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  color: rank <= 3 ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(merchant.merchant,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${merchant.transactionCount} transactions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            merchant.formattedAmount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
