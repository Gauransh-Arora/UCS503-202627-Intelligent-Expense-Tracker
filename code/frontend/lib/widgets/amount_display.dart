import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

enum AmountDisplayStyle { small, medium, large, hero }

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final AmountDisplayStyle style;
  final Color? color;
  final bool isExpense;
  final bool isIncome;
  final String? subtitle;
  final TextAlign textAlign;
  final bool showSign;

  const AmountDisplay({
    super.key,
    required this.amount,
    this.currencySymbol = '₹',
    this.style = AmountDisplayStyle.medium,
    this.color,
    this.isExpense = false,
    this.isIncome = false,
    this.subtitle,
    this.textAlign = TextAlign.start,
    this.showSign = false,
  });

  Color _resolveColor() {
    if (color != null) return color!;
    if (isExpense) return AppColors.debit;
    if (isIncome) return AppColors.credit;
    return AppColors.textPrimary;
  }

  double _getMainFontSize() {
    switch (style) {
      case AmountDisplayStyle.hero:
        return 34;
      case AmountDisplayStyle.large:
        return 24;
      case AmountDisplayStyle.medium:
        return 18;
      case AmountDisplayStyle.small:
        return 14;
    }
  }

  FontWeight _getFontWeight() {
    switch (style) {
      case AmountDisplayStyle.hero:
        return FontWeight.w600;
      case AmountDisplayStyle.large:
        return FontWeight.w600;
      case AmountDisplayStyle.medium:
        return FontWeight.w500;
      case AmountDisplayStyle.small:
        return FontWeight.w500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = _resolveColor();
    final mainSize = _getMainFontSize();
    final weight = _getFontWeight();

    final absAmount = amount.abs();
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 2,
    );
    final formattedFull = formatter.format(absAmount);
    final parts = formattedFull.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    final hasNonZeroDecimals = decimalPart != '00';

    final sign = showSign
        ? (amount < 0 || isExpense ? '− ' : (isIncome ? '+ ' : ''))
        : (amount < 0 ? '− ' : '');

    return Column(
      crossAxisAlignment: textAlign == TextAlign.end
          ? CrossAxisAlignment.end
          : (textAlign == TextAlign.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start),
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: textAlign,
          text: TextSpan(
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              color: effectiveColor,
              fontWeight: weight,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
            children: [
              if (sign.isNotEmpty)
                TextSpan(
                  text: sign,
                  style: TextStyle(
                    fontSize: mainSize * 0.9,
                    fontWeight: weight,
                  ),
                ),
              TextSpan(
                text: currencySymbol,
                style: TextStyle(
                  fontSize: mainSize * 0.85,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor.withValues(alpha: 0.85),
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: integerPart,
                style: TextStyle(fontSize: mainSize, fontWeight: weight),
              ),
              if (style == AmountDisplayStyle.hero ||
                  style == AmountDisplayStyle.large)
                if (hasNonZeroDecimals)
                  TextSpan(
                    text: '.$decimalPart',
                    style: TextStyle(
                      fontSize: mainSize * 0.65,
                      fontWeight: FontWeight.w500,
                      color: effectiveColor.withValues(alpha: 0.65),
                    ),
                  )
                else
                  const TextSpan()
              else if (hasNonZeroDecimals)
                TextSpan(
                  text: '.$decimalPart',
                  style: TextStyle(
                    fontSize: mainSize * 0.8,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              fontFamily: AppTheme.fontSans,
            ),
          ),
        ],
      ],
    );
  }
}
