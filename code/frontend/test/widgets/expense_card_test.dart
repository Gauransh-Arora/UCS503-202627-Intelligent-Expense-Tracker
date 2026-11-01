import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/models/expense_model.dart';
import 'package:intelligent_expense_tracker/widgets/expense_card.dart';

void main() {
  group('ExpenseCard Widget Tests', () {
    final sampleExpense = ExpenseModel(
      id: 'exp_1',
      merchant: 'Blue Tokai',
      amount: 420.0,
      date: DateTime(2026, 10, 24),
      category: 'Food & Dining',
      paymentMethod: 'upi',
    );

    testWidgets('renders merchant, category, and formatted method', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExpenseCard(expense: sampleExpense)),
        ),
      );

      expect(find.text('Blue Tokai'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.byType(ExpenseCard), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: sampleExpense,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExpenseCard));
      await tester.pumpAndSettle();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders date formatted when showDate is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: sampleExpense, showDate: true),
          ),
        ),
      );

      expect(find.text('24 Oct 2026'), findsOneWidget);
    });
  });
}
