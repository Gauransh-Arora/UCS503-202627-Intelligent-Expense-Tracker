import 'package:intl/intl.dart';
import '../core/utils/num_parser.dart';

class CategorySpending {
  final String category;
  final double amount;
  final double percentage;

  const CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  factory CategorySpending.fromJsonBackend(Map<String, dynamic> json) => CategorySpending(
        category: json['category_name']?.toString() ?? 'Unknown',
        amount: asDouble(json['total_amount']),
        percentage: asDouble(json['percentage']),
      );
}

class MonthlySpending {
  final String month;
  final double amount;

  const MonthlySpending({required this.month, required this.amount});

  factory MonthlySpending.fromJsonBackend(Map<String, dynamic> json) => MonthlySpending(
        month: json['month']?.toString() ?? '',
        amount: asDouble(json['total_amount']),
      );
}

class MerchantSpending {
  final String merchant;
  final double amount;
  final int transactionCount;
  final String category;

  const MerchantSpending({
    required this.merchant,
    required this.amount,
    required this.transactionCount,
    required this.category,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  factory MerchantSpending.fromJsonBackend(Map<String, dynamic> json) => MerchantSpending(
        merchant: json['merchant_name']?.toString() ?? 'Unknown',
        amount: asDouble(json['total_amount']),
        transactionCount: asInt(json['transaction_count'], 1),
        category: 'Unknown',
      );
}

class SpendingInsight {
  final String category;
  final double thisMonth;
  final double typicalMin;
  final double typicalMax;
  final bool isUnusual;
  final String description;

  const SpendingInsight({
    required this.category,
    required this.thisMonth,
    required this.typicalMin,
    required this.typicalMax,
    required this.isUnusual,
    required this.description,
  });

  String get formattedThisMonth {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(thisMonth);
  }

  String get formattedTypicalRange {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return '${formatter.format(typicalMin)} – ${formatter.format(typicalMax)}';
  }
}

class AnalyticsSummary {
  final double totalSpending;
  final double previousMonthSpending;
  final double income;
  final List<CategorySpending> byCategory;
  final List<MonthlySpending> monthlyTrend;
  final List<MerchantSpending> topMerchants;

  const AnalyticsSummary({
    required this.totalSpending,
    required this.previousMonthSpending,
    required this.income,
    required this.byCategory,
    required this.monthlyTrend,
    required this.topMerchants,
  });

  double get remaining => income - totalSpending;

  double get monthOverMonthChange =>
      previousMonthSpending > 0
          ? ((totalSpending - previousMonthSpending) / previousMonthSpending) * 100
          : 0.0;

  bool get isSpendingUp => totalSpending > previousMonthSpending;

  String get formattedTotal {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(totalSpending);
  }

  String get formattedIncome {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(income);
  }

  String get formattedRemaining {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(remaining);
  }

  factory AnalyticsSummary.fromJsonBackend(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalSpending: asDouble(json['current_month_spending']),
      previousMonthSpending: asDouble(json['previous_month_spending']),
      income: asDouble(json['income'], 60000.0),
      byCategory: (json['top_categories'] as List? ?? [])
          .map((e) => CategorySpending.fromJsonBackend(e as Map<String, dynamic>))
          .toList(),
      monthlyTrend: (json['spending_trend'] as List? ?? [])
          .map((e) => MonthlySpending.fromJsonBackend(e as Map<String, dynamic>))
          .toList(),
      topMerchants: (json['top_merchants'] as List? ?? [])
          .map((e) => MerchantSpending.fromJsonBackend(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthlyComparison {
  final String currentMonth;
  final double currentTotal;
  final int currentCount;
  final String previousMonth;
  final double previousTotal;
  final int previousCount;
  final double differenceAmount;
  final double percentageChange;
  final String verdict;
  final List<CategoryComparisonItem> categoryComparison;

  const MonthlyComparison({
    required this.currentMonth,
    required this.currentTotal,
    required this.currentCount,
    required this.previousMonth,
    required this.previousTotal,
    required this.previousCount,
    required this.differenceAmount,
    required this.percentageChange,
    required this.verdict,
    this.categoryComparison = const [],
  });

  factory MonthlyComparison.fromJson(Map<String, dynamic> json) {
    final list = json['category_comparison'] as List? ?? [];
    return MonthlyComparison(
      currentMonth: json['current_month']?.toString() ?? '',
      currentTotal: asDouble(json['current_total']),
      currentCount: asInt(json['current_count']),
      previousMonth: json['previous_month']?.toString() ?? '',
      previousTotal: asDouble(json['previous_total']),
      previousCount: asInt(json['previous_count']),
      differenceAmount: asDouble(json['difference_amount']),
      percentageChange: asDouble(json['percentage_change']),
      verdict: json['verdict'] as String? ?? 'Normal spending pattern',
      categoryComparison: list
          .map((e) => CategoryComparisonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategoryComparisonItem {
  final String categoryName;
  final double currentAmount;
  final double previousAmount;
  final double differenceAmount;
  final double percentageChange;

  const CategoryComparisonItem({
    required this.categoryName,
    required this.currentAmount,
    required this.previousAmount,
    required this.differenceAmount,
    required this.percentageChange,
  });

  factory CategoryComparisonItem.fromJson(Map<String, dynamic> json) => CategoryComparisonItem(
        categoryName: json['category_name']?.toString() ?? 'General',
        currentAmount: asDouble(json['current_amount']),
        previousAmount: asDouble(json['previous_amount']),
        differenceAmount: asDouble(json['difference_amount']),
        percentageChange: asDouble(json['percentage_change']),
      );
}

class SpendingSummaryResponse {
  final String summaryText;
  final String period;
  final double totalSpent;
  final int transactionCount;
  final String? topCategory;
  final String? topMerchant;
  final List<String> keyInsights;

  const SpendingSummaryResponse({
    required this.summaryText,
    required this.period,
    required this.totalSpent,
    required this.transactionCount,
    this.topCategory,
    this.topMerchant,
    this.keyInsights = const [],
  });

  factory SpendingSummaryResponse.fromJson(Map<String, dynamic> json) => SpendingSummaryResponse(
        summaryText: json['summary_text']?.toString() ?? '',
        period: json['period']?.toString() ?? '',
        totalSpent: asDouble(json['total_spent'] ?? json['total_amount']),
        transactionCount: asInt(json['transaction_count']),
        topCategory: json['top_category']?.toString(),
        topMerchant: json['top_merchant']?.toString(),
        keyInsights: (json['key_insights'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

class SpendingTrend {
  final String month;
  final int year;
  final double totalAmount;
  final int transactionCount;

  const SpendingTrend({
    required this.month,
    required this.year,
    required this.totalAmount,
    required this.transactionCount,
  });

  factory SpendingTrend.fromJson(Map<String, dynamic> json) => SpendingTrend(
        month: json['month']?.toString() ?? '',
        year: asInt(json['year'], DateTime.now().year),
        totalAmount: asDouble(json['total_amount']),
        transactionCount: asInt(json['transaction_count']),
      );
}

class ItemSpendingSummary {
  final String itemName;
  final double totalSpent;
  final int totalQuantity;
  final int transactionCount;

  const ItemSpendingSummary({
    required this.itemName,
    required this.totalSpent,
    required this.totalQuantity,
    required this.transactionCount,
  });

  factory ItemSpendingSummary.fromJson(Map<String, dynamic> json) => ItemSpendingSummary(
        itemName: json['item_name']?.toString() ?? '',
        totalSpent: asDouble(json['total_amount'] ?? json['total_spent']),
        totalQuantity: asInt(json['total_quantity'], 1),
        transactionCount: asInt(json['transaction_count'], 1),
      );
}

