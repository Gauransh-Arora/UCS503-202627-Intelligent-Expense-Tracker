import 'package:intl/intl.dart';
import '../core/utils/num_parser.dart';

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
      merchantName: json['merchant_name']?.toString() ?? 'Subscription',
      monthlyAmount: asDouble(json['monthly_amount']),
      annualAmount: asDouble(json['annual_amount']),
      frequency: json['frequency']?.toString() ?? 'monthly',
      confidence: asDouble(json['confidence'], 1.0),
      categoryName: json['category_name']?.toString(),
      typicalDay: asIntOrNull(json['typical_day']),
      status: json['status']?.toString() ?? 'active',
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
      merchantName: json['merchant_name']?.toString() ?? json['merchant']?.toString() ?? 'Recurring',
      amount: asDouble(json['amount'] ?? json['typical_amount']),
      frequency: json['frequency']?.toString() ?? 'monthly',
      category: json['category']?.toString() ?? json['category_name']?.toString(),
      nextExpected: json['next_expected_date'] != null
          ? DateTime.tryParse(json['next_expected_date'].toString())
          : (json['next_expected'] != null ? DateTime.tryParse(json['next_expected'].toString()) : null),
      count: asInt(json['occurrences'] ?? json['count'], 1),
    );
  }
}
