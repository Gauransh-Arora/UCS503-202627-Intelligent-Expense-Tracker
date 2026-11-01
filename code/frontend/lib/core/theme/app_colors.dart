import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Design tokens for "Intelligent Expense Tracker" (Duolingo-Inspired Theme).
///
/// Palette: Forest Green & Warm Off-White
/// - Friendly, engaging, approachable fintech companion
/// - Dark forest green (#164B35) for primary authority
/// - Deep green (#103D2C) for chunky button bottom depth
/// - Warm off-white (#F8F8F0) background canvas
/// - Soft mint (#DDF1E3) and light sage (#E8EFE6) for supportive surfaces
/// - Harmonized, playful semantic tones (expense #D96B63, income #31966A)
class AppColors {
  AppColors._();

  // ─── Brand & Core Forest Tokens ──────────────────────────────────────────
  /// Dark forest green - primary actions and active navigation states
  static const Color primary = Color(0xFF164B35);
  /// Deep green - tactile button bottom depth & high-contrast headers
  static const Color primaryDark = Color(0xFF103D2C);
  /// Main vibrant green - key highlights and progress indicators
  static const Color primaryMain = Color(0xFF238653);
  /// Bright accent green - energetic rewards, streak badges & active states
  static const Color primaryBright = Color(0xFF58B77A);

  // Aliases for compatibility
  static const Color ink = primary;
  static const Color inkLight = primaryDark;
  static const Color accent = primaryMain;
  static const Color accentMuted = mint;
  static const Color accentSubtle = sage;

  // ─── Canvas & Surfaces (Warm Off-White) ───────────────────────────────────
  /// Warm off-white page background
  static const Color background = Color(0xFFF8F8F0);
  /// Pale cream surface for layered sections
  static const Color surfaceCream = Color(0xFFF1F3E9);
  /// Clean white card surface
  static const Color surfaceCard = Color(0xFFFFFFFF);
  /// Soft mint for friendly pill highlights & interactive tiles
  static const Color mint = Color(0xFFDDF1E3);
  /// Light sage for divider outlines and card borders
  static const Color sage = Color(0xFFE8EFE6);

  static const Color surfaceElevated = surfaceCream;
  static const Color surfaceMuted = sage;

  // ─── Typography & Content ────────────────────────────────────────────────
  /// Deep forest ink text
  static const Color textPrimary = Color(0xFF20352A);
  /// Muted sage text for subtitles and metadata
  static const Color textSecondary = Color(0xFF78857C);
  /// Light muted text for placeholders and disabled states
  static const Color textTertiary = Color(0xFF9EABA1);
  /// Text on dark surfaces
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ─── Borders & Tactile Chunky Depth ──────────────────────────────────────
  static const Color border = Color(0xFFE0E8DE);
  static const Color borderSubtle = Color(0xFFE8EFE6);
  static const Color borderStrong = Color(0xFFC8D7C5);
  static const Color borderFocus = primaryMain;

  /// Dark green bevel depth for chunky primary buttons
  static const Color buttonDepth = Color(0xFF103D2C);
  /// Soft bevel depth for chunky secondary/white buttons
  static const Color buttonDepthLight = Color(0xFFD4DEC2);
  /// Card tactile bottom shadow
  static const Color cardDepth = Color(0x1F20352A);

  // ─── Semantic Tokens (Harmonized) ────────────────────────────────────────
  /// Expense / Debit: Warm crimson
  static const Color expense = Color(0xFFD96B63);
  static const Color expenseLight = Color(0xFFFBECEB);
  static const Color debit = expense;
  static const Color debitLight = expenseLight;
  static const Color danger = expense;
  static const Color dangerLight = expenseLight;

  /// Income / Credit / Success: Friendly emerald
  static const Color income = Color(0xFF31966A);
  static const Color incomeLight = Color(0xFFEBF7F1);
  static const Color credit = income;
  static const Color creditLight = incomeLight;
  static const Color success = income;
  static const Color successLight = incomeLight;

  /// Warning / Anomaly: Sunny amber
  static const Color warning = Color(0xFFE8B957);
  static const Color warningLight = Color(0xFFFDF7EA);

  /// Info / Metadata: Approachable sky blue
  static const Color info = Color(0xFF6C9BC7);
  static const Color infoLight = Color(0xFFEEF4FA);

  // ─── Category System (Coherent Forest Harmonized Palette) ────────────────
  static const List<Color> categorySwatches = [
    Color(0xFF238653), // Forest Green
    Color(0xFF6C9BC7), // Sky Blue
    Color(0xFFE8B957), // Warm Amber
    Color(0xFFD96B63), // Coral Red
    Color(0xFF8B68AA), // Muted Purple
    Color(0xFF31966A), // Emerald
    Color(0xFFC47D4C), // Terracotta
    Color(0xFF4A7C59), // Sage Green
  ];

  static const Color catFood = Color(0xFFC47D4C);
  static const Color catGroceries = Color(0xFF31966A);
  static const Color catTravel = Color(0xFF6C9BC7);
  static const Color catShopping = Color(0xFFE8B957);
  static const Color catBills = Color(0xFF238653);
  static const Color catHealth = Color(0xFFD96B63);
  static const Color catEntertainment = Color(0xFF8B68AA);
  static const Color catEducation = Color(0xFF4A7C59);
  static const Color catRent = Color(0xFF164B35);
  static const Color catSubscriptions = Color(0xFF6C9BC7);
  static const Color catOther = Color(0xFF78857C);

  /// Dynamic category color with stable hash fallback.
  static Color categoryColor(String category) {
    final clean = category.trim().toLowerCase();
    switch (clean) {
      case 'food':
      case 'food & dining':
        return catFood;
      case 'groceries':
      case 'grocery':
        return catGroceries;
      case 'travel':
      case 'transport':
      case 'transportation':
        return catTravel;
      case 'shopping':
        return catShopping;
      case 'bills':
      case 'utilities':
        return catBills;
      case 'health':
      case 'healthcare':
      case 'medical':
        return catHealth;
      case 'entertainment':
        return catEntertainment;
      case 'education':
        return catEducation;
      case 'rent':
      case 'housing':
        return catRent;
      case 'subscriptions':
      case 'subscription':
        return catSubscriptions;
      default:
        if (clean.isEmpty) return catOther;
        final hash = clean.runes.fold<int>(0, (prev, elem) => prev + elem);
        return categorySwatches[hash % categorySwatches.length];
    }
  }

  /// Category icon using Lucide icons.
  static IconData categoryIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'food':
      case 'food & dining':
        return LucideIcons.utensils;
      case 'groceries':
      case 'grocery':
        return LucideIcons.shoppingCart;
      case 'travel':
      case 'transport':
      case 'transportation':
        return LucideIcons.car;
      case 'shopping':
        return LucideIcons.shoppingBag;
      case 'bills':
      case 'utilities':
        return LucideIcons.receipt;
      case 'health':
      case 'healthcare':
      case 'medical':
        return LucideIcons.heartPulse;
      case 'entertainment':
        return LucideIcons.film;
      case 'education':
        return LucideIcons.graduationCap;
      case 'rent':
      case 'housing':
        return LucideIcons.home;
      case 'subscriptions':
      case 'subscription':
        return LucideIcons.refreshCw;
      default:
        return LucideIcons.tag;
    }
  }
}
