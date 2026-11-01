import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/widgets/empty_state.dart';

void main() {
  group('EmptyState Widget Tests', () {
    testWidgets('renders title and description without action button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No transactions found',
              description: 'Try adjusting filters or import a bank statement.',
            ),
          ),
        ),
      );

      expect(find.text('No transactions found'), findsOneWidget);
      expect(
        find.text('Try adjusting filters or import a bank statement.'),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('renders action button and invokes onAction callback', (
      WidgetTester tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No expenses yet',
              description: 'Start tracking by scanning a receipt.',
              actionLabel: 'Add Expense',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);

      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      expect(actionTriggered, isTrue);
    });
  });
}
