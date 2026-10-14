import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      expectedPrice: (json['expected_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      description: json['description'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      url: json['url'] as String?,
      purchaseReadiness: (json['purchase_readiness'] as num?)?.toDouble(),
      estimatedMonths: (json['estimated_months'] as num?)?.toDouble(),
      verdict: json['verdict'] as String?,
      discretionaryBudget: (json['discretionary_budget'] as num?)?.toDouble(),
      isPurchased: json['is_purchased'] as bool? ?? false,
      addedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      analysis: json['description'] as String? ?? json['analysis'] as String?,
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
      wishlistItemId: json['wishlist_item_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      expectedPrice: (json['expected_price'] as num?)?.toDouble() ?? 0.0,
      purchaseReadiness: (json['purchase_readiness'] as num?)?.toDouble() ?? 0.0,
      estimatedMonths: (json['estimated_months'] as num?)?.toDouble(),
      monthlyDiscretionary: (json['monthly_discretionary'] as num?)?.toDouble() ?? 0.0,
      avgMonthlySpending: (json['avg_monthly_spending'] as num?)?.toDouble() ?? 0.0,
      verdict: json['verdict'] as String? ?? 'Possible',
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
      monthlyDiscretionary: (json['monthly_discretionary'] as num?)?.toDouble() ?? 0.0,
      avgMonthlySpending: (json['avg_monthly_spending'] as num?)?.toDouble() ?? 0.0,
      monthlyRecurring: (json['monthly_recurring'] as num?)?.toDouble() ?? 0.0,
      savingsReserve: (json['savings_reserve'] as num?)?.toDouble() ?? 0.0,
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
