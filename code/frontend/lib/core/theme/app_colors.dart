import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF1A1F4B);
  static const Color primaryLight = Color(0xFF2D3580);
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentLight = Color(0xFF8B85FF);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Backgrounds
  static const Color background = Color(0xFFF8F9FF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF0F1FF);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF6C63FF);

  // Category colors
  static const Color catFood = Color(0xFFFF6B6B);
  static const Color catTravel = Color(0xFF4ECDC4);
  static const Color catShopping = Color(0xFFFFBE0B);
  static const Color catBills = Color(0xFF8338EC);
  static const Color catHealth = Color(0xFF06D6A0);
  static const Color catEntertainment = Color(0xFFFF006E);
  static const Color catEducation = Color(0xFF3A86FF);
  static const Color catOther = Color(0xFF8B8B8B);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A1F4B), Color(0xFF2D3580)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return catFood;
      case 'travel':
      case 'transport':
        return catTravel;
      case 'shopping':
        return catShopping;
      case 'bills':
      case 'utilities':
        return catBills;
      case 'health':
        return catHealth;
      case 'entertainment':
        return catEntertainment;
      case 'education':
        return catEducation;
      default:
        return catOther;
    }
  }

  static String categoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return '🍔';
      case 'travel':
      case 'transport':
        return '🚕';
      case 'shopping':
        return '🛒';
      case 'bills':
      case 'utilities':
        return '💡';
      case 'health':
        return '💊';
      case 'entertainment':
        return '🎬';
      case 'education':
        return '📚';
      default:
        return '💰';
    }
  }
}
