import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/features/add_expense/ocr_flow/ocr_review_screen.dart';

void main() {
  testWidgets('OcrReviewScreen displays extracted draft data, confidence, and action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockDraft = {
      'document_id': 'doc-12345',
      'merchant_name': 'Blue Tokai Coffee',
      'amount': 450.0,
      'date': '2026-10-15',
      'category_suggestion': 'Food & Dining',
      'confidence': 0.95,
      'items': [
        {'name': 'Pour Over Coffee', 'quantity': 1, 'unit_price': 250.0, 'total_price': 250.0},
        {'name': 'Croissant', 'quantity': 1, 'unit_price': 200.0, 'total_price': 200.0},
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OcrReviewScreen(ocrData: mockDraft),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify merchant and amount are rendered in text controllers
    expect(find.text('Blue Tokai Coffee'), findsOneWidget);
    expect(find.text('450.0'), findsOneWidget);

    // Verify category and date
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('2026-10-15'), findsOneWidget);

    // Verify line items
    expect(find.text('Pour Over Coffee'), findsOneWidget);
    expect(find.text('Croissant'), findsOneWidget);

    // Verify Confirm and Discard buttons exist
    expect(find.text('Confirm Expense'), findsOneWidget);
    expect(find.text('Discard Draft'), findsOneWidget);
  });
}
