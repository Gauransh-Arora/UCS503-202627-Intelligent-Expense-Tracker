import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/main.dart';

void main() {
  testWidgets('App smoke test - verifies app initializes and renders', (WidgetTester tester) async {
    await tester.pumpWidget(const IntelligentExpenseTrackerApp());
    // Advance past splash animation and delay
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(IntelligentExpenseTrackerApp), findsOneWidget);
  });
}
