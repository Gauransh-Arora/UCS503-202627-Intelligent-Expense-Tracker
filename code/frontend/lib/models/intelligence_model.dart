import 'package:intl/intl.dart';

class SubscriptionResponseModel {
  final String merchantName;
  final double monthlyAmount;
  final double annualAmount;
  final String frequency;
  final double confidence;
  final String? categoryName;
  final int? typicalDay;
  final String status;

  const SubscriptionResponseModel({
    required this.merchantName,
    required this.monthlyAmount,
    required this.annualAmount,
    required this.frequency,
    required this.confidence,
    this.categoryName,
    this.typicalDay,
    this.status = 'active',
  });

  String get formattedMonthlyAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(monthlyAmount);
  }

  String get formattedAnnualAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(annualAmount);
  }

  factory SubscriptionResponseModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponseModel(
      merchantName: json['merchant_name'] as String? ?? 'Subscription',
      monthlyAmount: (json['monthly_amount'] as num?)?.toDouble() ?? 0.0,
      annualAmount: (json['annual_amount'] as num?)?.toDouble() ?? 0.0,
      frequency: json['frequency'] as String? ?? 'monthly',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      categoryName: json['category_name'] as String?,
      typicalDay: json['typical_day'] as int?,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class DetectedRecurringModel {
  final String merchantName;
  final double amount;
  final String frequency;
  final String? category;
  final DateTime? nextExpected;
  final int count;

  const DetectedRecurringModel({
    required this.merchantName,
    required this.amount,
    required this.frequency,
    this.category,
    this.nextExpected,
    this.count = 1,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  factory DetectedRecurringModel.fromJson(Map<String, dynamic> json) {
    return DetectedRecurringModel(
      merchantName: json['merchant_name'] as String? ?? json['merchant'] as String? ?? 'Recurring',
      amount: (json['amount'] as num?)?.toDouble() ?? (json['typical_amount'] as num?)?.toDouble() ?? 0.0,
      frequency: json['frequency'] as String? ?? 'monthly',
      category: json['category'] as String? ?? json['category_name'] as String?,
      nextExpected: json['next_expected_date'] != null
          ? DateTime.tryParse(json['next_expected_date'].toString())
          : (json['next_expected'] != null ? DateTime.tryParse(json['next_expected'].toString()) : null),
      count: json['occurrences'] as int? ?? json['count'] as int? ?? 1,
    );
  }
}
