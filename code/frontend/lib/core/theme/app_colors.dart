import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette (Blue-first)
  static const Color primary = Color(0xFF2F80ED); // Primary blue
  static const Color primaryDark = Color(0xFF1769D1); // Dark blue
  static const Color primaryLight = Color(0xFFEAF3FF); // Light blue
  static const Color accent = Color(0xFF2F80ED); // Same as primary for consistency
  static const Color accentLight = Color(0xFFEAF3FF);

  // Semantic colors
  static const Color success = Color(0xFF22C55E); // Green for success only
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B); // Warm yellow/orange
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444); // Restrained red
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Warm very-light neutral
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF5F9FF); // Very light blue

  // Text
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE6EAF0);
  static const Color borderFocus = Color(0xFF2F80ED); // Focus color is primary blue

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
    colors: [Color(0xFF4092FF), Color(0xFF1769D1)], // Brighter blue to darker blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4092FF), Color(0xFF1769D1)],
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

  static IconData categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return Icons.fastfood_rounded;
      case 'travel':
      case 'transport':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
      case 'utilities':
        return Icons.lightbulb_rounded;
      case 'health':
        return Icons.local_pharmacy_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'education':
        return Icons.school_rounded;
      default:
        return Icons.monetization_on_rounded;
    }
  }
}
