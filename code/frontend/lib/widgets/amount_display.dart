import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';

enum AmountDisplayStyle { small, medium, large, hero }

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final AmountDisplayStyle style;
  final Color? color;
  final bool isExpense;
  final bool isIncome;
  final String? subtitle;

  const AmountDisplay({
    super.key,
    required this.amount,
    this.currencySymbol = '₹',
    this.style = AmountDisplayStyle.medium,
    this.color,
    this.isExpense = false,
    this.isIncome = false,
    this.subtitle,
  });

  String get _formattedValue {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: currencySymbol,
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  TextStyle _getTextStyle(BuildContext context) {
    Color textColor = color ?? AppColors.textPrimary;
    if (isExpense) textColor = AppColors.danger;
    if (isIncome) textColor = AppColors.success;

    switch (style) {
      case AmountDisplayStyle.hero:
        return TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -1.0,
        );
      case AmountDisplayStyle.large:
        return TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.5,
        );
      case AmountDisplayStyle.medium:
        return TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
        );
      case AmountDisplayStyle.small:
        return TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formattedValue,
          style: _getTextStyle(context),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}
