import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/widgets/primary_button.dart';

void main() {
  group('PrimaryButton Widget Tests', () {
    testWidgets('renders button label and fires onPressed when clicked', (
      WidgetTester tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Save Transaction',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Save Transaction'), findsOneWidget);
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('renders loading state and disables interactions', (
      WidgetTester tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Processing',
              isLoading: true,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Label is replaced with loading indicator
      expect(find.text('Processing'), findsNothing);

      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('renders disabled state when onPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(label: 'Disabled Action', onPressed: null),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.enabled, isFalse);
    });

    testWidgets('renders icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Add Receipt',
              icon: const Icon(Icons.receipt_outlined),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_outlined), findsOneWidget);
      expect(find.text('Add Receipt'), findsOneWidget);
    });
  });
}
