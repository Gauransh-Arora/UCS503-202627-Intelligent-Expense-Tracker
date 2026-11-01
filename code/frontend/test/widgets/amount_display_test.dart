import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/widgets/amount_display.dart';

void main() {
  group('AmountDisplay Widget Tests', () {
    testWidgets('renders amount with Indian rupee symbol and formatting', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmountDisplay(
              amount: 123456.50,
              style: AmountDisplayStyle.medium,
            ),
          ),
        ),
      );

      expect(find.byType(AmountDisplay), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);

      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;

      expect(textSpan.toPlainText(), '₹ 1,23,456.50');
    });

    testWidgets('renders with sign prefix when showSign is enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amount: 500, isExpense: true, showSign: true),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;

      // Minus sign should be present before currency symbol
      expect(textSpan.toPlainText(), '− ₹ 500');
    });

    testWidgets(
      'renders positive income with plus sign when showSign is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AmountDisplay(
                amount: 25000,
                isIncome: true,
                showSign: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(find.byType(RichText));
        final textSpan = richText.text as TextSpan;

        expect(textSpan.toPlainText(), '+ ₹ 25,000');
      },
    );

    testWidgets('renders hero style without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amount: 9999.0, style: AmountDisplayStyle.hero),
          ),
        ),
      );

      expect(find.byType(AmountDisplay), findsOneWidget);
    });
  });
}
