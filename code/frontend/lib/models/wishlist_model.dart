import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../core/utils/num_parser.dart';

class WishlistItemModel {
  final String id;
  final String name;
  final double expectedPrice;
  final String currency;
  final String? description;
  final String priority; // 'low', 'medium', 'high'
  final String? url;
  final double? purchaseReadiness; // 0 - 100
  final double? estimatedMonths;
  final String? verdict; // 'Comfortable', 'Possible', 'Not recommended currently'
  final double? discretionaryBudget;
  final bool isPurchased;
  final DateTime addedAt;
  final IconData? imageIcon;
  final String? analysis;

  final String? _readinessOverride;

  const WishlistItemModel({
    required this.id,
    required this.name,
    required this.expectedPrice,
    this.currency = 'INR',
    this.description,
    this.priority = 'medium',
    this.url,
    this.purchaseReadiness,
    this.estimatedMonths,
    this.verdict,
    this.discretionaryBudget,
    this.isPurchased = false,
    required this.addedAt,
    this.imageIcon,
    this.analysis,
    String? readiness,
  }) : _readinessOverride = readiness;

  String get readiness {
    if (_readinessOverride != null) return _readinessOverride;
    if (verdict != null) {
      if (verdict!.toLowerCase().contains('comfortable')) return 'Comfortable';
      if (verdict!.toLowerCase().contains('possible')) return 'Possible';
      return 'Not Recommended';
    }
    if (purchaseReadiness != null) {
      if (purchaseReadiness! >= 80) return 'Comfortable';
      if (purchaseReadiness! >= 50) return 'Possible';
      return 'Not Recommended';
    }
    return 'Possible';
  }

  String get formattedPrice {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(expectedPrice);
  }

  IconData get readinessIcon {
    switch (readiness) {
      case 'Comfortable':
        return Icons.check_circle_rounded;
      case 'Possible':
        return Icons.info_rounded;
      case 'Not Recommended':
      default:
        return Icons.cancel_rounded;
    }
  }

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      expectedPrice: asDouble(json['expected_price'] ?? json['price']),
      currency: json['currency']?.toString() ?? 'INR',
      description: json['description']?.toString(),
      priority: json['priority']?.toString() ?? 'medium',
      url: json['url']?.toString(),
      purchaseReadiness: asDoubleOrNull(json['purchase_readiness']),
      estimatedMonths: asDoubleOrNull(json['estimated_months']),
      verdict: json['verdict']?.toString(),
      discretionaryBudget: asDoubleOrNull(json['discretionary_budget']),
      isPurchased: json['is_purchased'] as bool? ?? false,
      addedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      analysis: json['description']?.toString() ?? json['analysis']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'expected_price': expectedPrice,
        'currency': currency,
        'description': description,
        'priority': priority,
        'url': url,
      };
}

class ReadinessResponseModel {
  final String wishlistItemId;
  final String name;
  final double expectedPrice;
  final double purchaseReadiness;
  final double? estimatedMonths;
  final double monthlyDiscretionary;
  final double avgMonthlySpending;
  final String verdict;
  final List<String> analysisNotes;

  const ReadinessResponseModel({
    required this.wishlistItemId,
    required this.name,
    required this.expectedPrice,
    required this.purchaseReadiness,
    this.estimatedMonths,
    required this.monthlyDiscretionary,
    required this.avgMonthlySpending,
    required this.verdict,
    this.analysisNotes = const [],
  });

  factory ReadinessResponseModel.fromJson(Map<String, dynamic> json) {
    return ReadinessResponseModel(
      wishlistItemId: json['wishlist_item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      expectedPrice: asDouble(json['expected_price']),
      purchaseReadiness: asDouble(json['purchase_readiness']),
      estimatedMonths: asDoubleOrNull(json['estimated_months']),
      monthlyDiscretionary: asDouble(json['monthly_discretionary']),
      avgMonthlySpending: asDouble(json['avg_monthly_spending']),
      verdict: json['verdict']?.toString() ?? 'Possible',
      analysisNotes: (json['analysis_notes'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class DiscretionaryBudgetModel {
  final double monthlyDiscretionary;
  final double avgMonthlySpending;
  final double monthlyRecurring;
  final double savingsReserve;
  final List<String> analysisNotes;

  const DiscretionaryBudgetModel({
    required this.monthlyDiscretionary,
    required this.avgMonthlySpending,
    required this.monthlyRecurring,
    required this.savingsReserve,
    this.analysisNotes = const [],
  });

  factory DiscretionaryBudgetModel.fromJson(Map<String, dynamic> json) {
    return DiscretionaryBudgetModel(
      monthlyDiscretionary: asDouble(json['monthly_discretionary']),
      avgMonthlySpending: asDouble(json['avg_monthly_spending']),
      monthlyRecurring: asDouble(json['monthly_recurring']),
      savingsReserve: asDouble(json['savings_reserve']),
      analysisNotes: (json['analysis_notes'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class RecurringExpenseModel {
  final String id;
  final String merchant;
  final double amount;
  final String category;
  final String interval; // 'monthly', 'weekly', 'yearly'
  final DateTime nextExpected;
  final IconData? icon;

  const RecurringExpenseModel({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.interval,
    required this.nextExpected,
    this.icon,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  String get formattedInterval {
    switch (interval.toLowerCase()) {
      case 'monthly':
        return '/ month';
      case 'weekly':
        return '/ week';
      case 'yearly':
        return '/ year';
      default:
        return interval;
    }
  }

  String get nextExpectedFormatted {
    return DateFormat('dd MMM').format(nextExpected);
  }
}
