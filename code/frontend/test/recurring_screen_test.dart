import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/models/intelligence_model.dart';

void main() {
  group('DetectedRecurringModel JSON deserialization', () {
    test('parses amount from average_amount correctly', () {
      final json = {
        'merchant_name': 'Airtel Broadband',
        'average_amount': 999.0,
        'frequency': 'monthly',
        'confidence': 95.0,
        'transaction_count': 5,
        'category': 'Bills & Utilities',
        'next_expected_date': '2026-11-20',
      };

      final model = DetectedRecurringModel.fromJson(json);
      expect(model.merchantName, 'Airtel Broadband');
      expect(model.amount, 999.0);
      expect(model.formattedAmount, '₹999');
      expect(model.frequency, 'monthly');
      expect(model.category, 'Bills & Utilities');
      expect(model.count, 5);
      expect(model.nextExpected, DateTime.parse('2026-11-20'));
    });

    test('parses amount from typical_amount or amount keys as fallback', () {
      final json1 = {
        'merchant': 'Tata Power',
        'typical_amount': 1500.50,
        'frequency': 'monthly',
      };
      final model1 = DetectedRecurringModel.fromJson(json1);
      expect(model1.merchantName, 'Tata Power');
      expect(model1.amount, 1500.50);

      final json2 = {
        'merchant_name': 'Gym Membership',
        'amount': 2000.0,
        'frequency': 'monthly',
      };
      final model2 = DetectedRecurringModel.fromJson(json2);
      expect(model2.merchantName, 'Gym Membership');
      expect(model2.amount, 2000.0);
    });

    test('handles missing or null fields gracefully', () {
      final json = <String, dynamic>{};
      final model = DetectedRecurringModel.fromJson(json);
      expect(model.merchantName, 'Recurring');
      expect(model.amount, 0.0);
      expect(model.frequency, 'monthly');
      expect(model.category, isNull);
      expect(model.nextExpected, isNull);
      expect(model.count, 1);
    });
  });
}
