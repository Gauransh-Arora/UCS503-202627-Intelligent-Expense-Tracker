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

    test('consumePendingShare provides atomic single consumption', () {
      final share = PendingShare(
        type: SharedType.file,
        payload: '/storage/emulated/0/DCIM/receipt.jpg',
      );
      ShareIntentService.setPendingShareForTesting(share);

      expect(ShareIntentService.hasPendingShare, isTrue);
      expect(
        ShareIntentService.pendingShare?.payload,
        '/storage/emulated/0/DCIM/receipt.jpg',
      );

      final consumed = ShareIntentService.consumePendingShare();
      expect(consumed?.payload, '/storage/emulated/0/DCIM/receipt.jpg');
      expect(ShareIntentService.hasPendingShare, isFalse);
      expect(ShareIntentService.pendingShare, isNull);

      final secondConsume = ShareIntentService.consumePendingShare();
      expect(secondConsume, isNull);
    });

    test(
      'waitForInitialShare resolves without throwing on timeout or empty',
      () async {
        final stopwatch = Stopwatch()..start();
        await ShareIntentService.waitForInitialShare(
          timeout: const Duration(milliseconds: 50),
        );
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(40));
      },
    );

    test(
      'consumePendingShare handles text payment shares with extracted fields',
      () {
        final share = PendingShare(
          type: SharedType.text,
          payload: 'Payment of Rs. 450 to Swiggy UPI Txn: 1234567890',
          extra: {
            'amount': '450',
            'merchant': 'Swiggy',
            'note': 'UPI Txn: 1234567890',
          },
        );
        ShareIntentService.setPendingShareForTesting(share);

        expect(ShareIntentService.hasPendingShare, isTrue);
        final consumed = ShareIntentService.consumePendingShare();
        expect(consumed?.type, SharedType.text);
        expect(consumed?.extra?['amount'], '450');
        expect(consumed?.extra?['merchant'], 'Swiggy');
        expect(ShareIntentService.hasPendingShare, isFalse);
      },
    );
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
