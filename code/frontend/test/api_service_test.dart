import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/services/api_service.dart';
import 'package:intelligent_expense_tracker/models/expense_model.dart';

void main() {
  group('ApiService & Models Unit Tests', () {
    test('ApiService baseUrl is dynamic and non-empty', () {
      expect(ApiService.baseUrl, isNotEmpty);
      expect(ApiService.baseUrl.startsWith('http'), isTrue);
    });

    test('ExpenseModel serializes and deserializes accurately', () {
      final jsonMap = {
        'id': 'exp-001',
        'merchant': 'Starbucks Coffee',
        'amount': 420.50,
        'date': '2026-10-20T10:30:00.000',
        'category': 'Food & Dining',
        'paymentMethod': 'UPI',
        'source': 'manual',
        'notes': 'Coffee and pastry',
        'isRecurring': false,
        'items': [],
      };

      final expense = ExpenseModel.fromJson(jsonMap);
      expect(expense.id, 'exp-001');
      expect(expense.merchant, 'Starbucks Coffee');
      expect(expense.amount, 420.50);
      expect(expense.category, 'Food & Dining');
      expect(expense.paymentMethod, 'UPI');

      final serialized = expense.toJson();
      expect(serialized['id'], 'exp-001');
      expect(serialized['merchant'], 'Starbucks Coffee');
      expect(serialized['amount'], 420.50);
    });
  });
}
