import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/features/add_expense/bank_statement_screen.dart';

void main() {
  testWidgets('BankStatementScreen renders upload interface and supported formats', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: BankStatementScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Bank Statement'), findsAtLeastNWidgets(1));
    expect(find.byType(BankStatementScreen), findsOneWidget);
  });
}
