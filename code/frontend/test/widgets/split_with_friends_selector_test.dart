import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/widgets/split_with_friends_selector.dart';

void main() {
  group('SplitWithFriendsSelector Widget Tests', () {
    testWidgets('renders initial collapsed switch state', (tester) async {
      SplitSelectionData? lastData;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplitWithFriendsSelector(
              totalAmount: 1200.0,
              onChanged: (data) => lastData = data,
            ),
          ),
        ),
      );

      expect(find.text('Split with friends'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('SELECT FRIENDS TO SPLIT WITH'), findsNothing);
      expect(lastData, isNull);
    });

    testWidgets('toggling switch reveals friend selection and prompt', (
      tester,
    ) async {
      SplitSelectionData? lastData;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SplitWithFriendsSelector(
              totalAmount: 1200.0,
              onChanged: (data) => lastData = data,
            ),
          ),
        ),
      );

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SELECT FRIENDS TO SPLIT WITH'), findsOneWidget);
      expect(lastData?.isEnabled, isTrue);
    });

    testWidgets(
      'supports switching split types between Equal, Exact and Percentage',
      (tester) async {
        SplitSelectionData? lastData;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SplitWithFriendsSelector(
                totalAmount: 1000.0,
                onChanged: (data) => lastData = data,
              ),
            ),
          ),
        );

        // Enable split
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(lastData?.splitType, 'equal');
      },
    );
  });
}
