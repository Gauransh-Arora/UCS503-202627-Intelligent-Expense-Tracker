import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelligent_expense_tracker/services/api_service.dart';
import 'package:intelligent_expense_tracker/features/analytics/analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSummaryData = {
    'current_month_spending': 12500.0,
    'previous_month_spending': 11000.0,
    'income': 60000.0,
    'top_categories': [
      {
        'category_name': 'Food & Dining',
        'total_amount': 5000.0,
        'percentage': 40.0,
      },
      {'category_name': 'Shopping', 'total_amount': 3500.0, 'percentage': 28.0},
    ],
    'top_merchants': [
      {
        'merchant_name': 'Amazon',
        'total_amount': 3000.0,
        'transaction_count': 4,
      },
    ],
    'monthly_trend': [
      {'month': '2026-09', 'total_amount': 10500.0},
      {'month': '2026-10', 'total_amount': 11000.0},
      {'month': '2026-11', 'total_amount': 12500.0},
    ],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clearToken();
    ApiService.client = MockClient((request) async {
      if (request.url.path.contains('/analytics/summary')) {
        return http.Response(
          json.encode(mockSummaryData),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });
  });

  tearDown(() {
    ApiService.client = http.Client();
  });

  testWidgets(
    'AnalyticsScreen renders month switcher and supports previous month navigation',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));

      // Initial pump & settle for FutureBuilder
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final currentMonthLabel = DateFormat('MMM yyyy').format(now);
      expect(find.text(currentMonthLabel), findsOneWidget);

      // Verify Previous and Next buttons exist
      final prevBtn = find.byTooltip('Previous month');
      final nextBtn = find.byTooltip('Next month');
      expect(prevBtn, findsOneWidget);
      expect(nextBtn, findsOneWidget);

      // Total card rendered
      expect(find.text('Total Spending'), findsOneWidget);

      // Tap Previous month
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      final prevMonth = DateTime(now.year, now.month - 1);
      final prevMonthLabel = DateFormat('MMM yyyy').format(prevMonth);
      expect(find.text(prevMonthLabel), findsOneWidget);

      // Tap Next month to return to current month
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text(currentMonthLabel), findsOneWidget);
    },
  );

  testWidgets(
    'AnalyticsScreen opens month picker sheet when month pill is clicked',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final currentMonthLabel = DateFormat('MMM yyyy').format(now);
      await tester.tap(find.text(currentMonthLabel));
      await tester.pumpAndSettle();

      // Verify BottomSheet opened with title and 'Current' tag
      expect(find.text('Select Month'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
    },
  );

  testWidgets(
    'AnalyticsScreen renders monthly spending trend with formatted, non-overlapping month labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pumpAndSettle();

      // Scroll down to reveal Monthly Trend section
      await tester.scrollUntilVisible(find.text('Monthly Trend'), 200);
      await tester.pumpAndSettle();

      // Trend data has 2026-09, 2026-10, 2026-11
      // Verify raw 'YYYY-MM' strings are NOT rendered on the chart axis
      expect(find.text('2026-09'), findsNothing);
      expect(find.text('2026-10'), findsNothing);
      expect(find.text('2026-11'), findsNothing);

      // Verify formatted short month abbreviations are present
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('Nov'), findsOneWidget);
    },
  );
}
