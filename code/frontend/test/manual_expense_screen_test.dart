import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelligent_expense_tracker/services/api_service.dart';
import 'package:intelligent_expense_tracker/features/add_expense/manual_expense_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockBackendCategories = [
    {'id': 'cat-1', 'name': 'Food', 'icon': '🍔', 'is_default': true},
    {'id': 'cat-2', 'name': 'Groceries', 'icon': '🛒', 'is_default': true},
    {'id': 'cat-3', 'name': 'Transport', 'icon': '🚗', 'is_default': true},
    {'id': 'cat-4', 'name': 'Shopping', 'icon': '🛍️', 'is_default': true},
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clearToken();
    ApiService.client = MockClient((request) async {
      if (request.url.path.contains('/categories')) {
        return http.Response(
          json.encode(mockBackendCategories),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.client = http.Client();
  });

  testWidgets(
    'ManualExpenseScreen mounts without DropdownButton value mismatch exception',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ManualExpenseScreen()));

      // Initial pump
      await tester.pump();

      // Verify initial elements
      expect(find.text('Add Expense Manually'), findsOneWidget);
      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);

      // Wait for _loadCategories async resolution
      await tester.pumpAndSettle();

      // Verify categories loaded without throwing DropdownButton exception
      expect(tester.takeException(), isNull);

      // Verify DropdownFormField exists and resolved safely
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    },
  );
}
