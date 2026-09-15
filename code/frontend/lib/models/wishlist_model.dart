import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class WishlistItemModel {
  final String id;
  final String name;
  final double expectedPrice;
  final String readiness; // 'Comfortable', 'Possible', 'Not Recommended'
  final String? analysis;
  final IconData? imageIcon;
  final DateTime addedAt;

  const WishlistItemModel({
    required this.id,
    required this.name,
    required this.expectedPrice,
    required this.readiness,
    this.analysis,
    this.imageIcon,
    required this.addedAt,
  });

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
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
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
    switch (interval) {
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
