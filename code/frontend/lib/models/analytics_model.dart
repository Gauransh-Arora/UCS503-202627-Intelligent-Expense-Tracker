import 'package:intl/intl.dart';

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
        category: json['category_name'] ?? 'Unknown',
        amount: (json['total_amount'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class MonthlySpending {
  final String month;
  final double amount;

  const MonthlySpending({required this.month, required this.amount});

  factory MonthlySpending.fromJsonBackend(Map<String, dynamic> json) => MonthlySpending(
        month: json['month'],
        amount: (json['total_amount'] as num).toDouble(),
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
        merchant: json['merchant_name'],
        amount: (json['total_amount'] as num).toDouble(),
        transactionCount: json['transaction_count'] ?? 1,
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
      ((totalSpending - previousMonthSpending) / previousMonthSpending) * 100;

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
      totalSpending: (json['current_month_spending'] as num).toDouble(),
      previousMonthSpending: (json['previous_month_spending'] as num).toDouble(),
      income: 60000, // Hardcoded for now as backend doesn't provide income
      byCategory: (json['top_categories'] as List? ?? [])
          .map((e) => CategorySpending.fromJsonBackend(e))
          .toList(),
      monthlyTrend: (json['spending_trend'] as List? ?? [])
          .map((e) => MonthlySpending.fromJsonBackend(e))
          .toList(),
      topMerchants: (json['top_merchants'] as List? ?? [])
          .map((e) => MerchantSpending.fromJsonBackend(e))
          .toList(),
    );
  }
}
