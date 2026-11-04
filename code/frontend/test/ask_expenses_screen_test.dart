import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intelligent_expense_tracker/features/ask_expenses/ask_expenses_screen.dart';
import 'package:intelligent_expense_tracker/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'dummy_token'});
    ApiService.clearToken();
    ApiService.client = MockClient((request) async {
      if (request.url.path.contains('/auth/me')) {
        return http.Response(
          json.encode({
            'id': 'user-123',
            'email': 'test@example.com',
            'full_name': 'Test User',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/ai/query')) {
        return http.Response(
          json.encode({
            'question': 'How much did I spend?',
            'answer': 'You spent ₹1,200 this month.',
            'query_type': 'total_spending',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.client = http.Client();
  });

  testWidgets(
    'AskExpensesScreen mounts without layout overflow when keyboard opens',
    (tester) async {
      // Set a compact phone size screen (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AskExpensesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ask Expenses'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Simulate keyboard opening (bottom insets = 300)
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow happened
      expect(tester.takeException(), isNull);

      // Submit a query
      await tester.enterText(find.byType(TextField), 'How much did I spend?');
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // While typing indicator is visible with keyboard open, verify no overflow
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify response is rendered in chat
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('You spent ₹1,200 this month.'),
        ),
        findsOneWidget,
      );
    },
  );
}
