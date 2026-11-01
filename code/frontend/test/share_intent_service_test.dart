import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/navigation/main_navigation.dart';
import 'package:intelligent_expense_tracker/features/home/home_screen.dart';
import 'package:intelligent_expense_tracker/features/expenses/expenses_screen.dart';
import 'package:intelligent_expense_tracker/services/share_intent_service.dart';

void main() {
  group('ShareIntentService Tests', () {
    setUp(() {
      ShareIntentService.dispose();
    });

    test('Initial state has no pending share and is not ready', () {
      expect(ShareIntentService.hasPendingShare, isFalse);
      expect(ShareIntentService.isReady, isFalse);
    });

    test('onAppReady marks service ready', () {
      ShareIntentService.onAppReady();
      expect(ShareIntentService.isReady, isTrue);
      expect(ShareIntentService.hasPendingShare, isFalse);
    });

    test('dispose resets state cleanly', () {
      ShareIntentService.onAppReady();
      ShareIntentService.dispose();
      expect(ShareIntentService.isReady, isFalse);
      expect(ShareIntentService.hasPendingShare, isFalse);
    });
  });

  group('MainNavigation Lazy Tab Loading', () {
    testWidgets(
      'Only HomeScreen is mounted on startup; Expenses is deferred until tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: MainNavigation()));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ExpensesScreen), findsNothing);

        await tester.tap(find.text('Expenses').last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ExpensesScreen), findsOneWidget);
      },
    );
  });
}
