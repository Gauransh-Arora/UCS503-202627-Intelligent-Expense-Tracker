import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelligent_expense_tracker/services/api_service.dart';
import 'package:intelligent_expense_tracker/models/expense_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService & Models Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ApiService baseUrl is dynamic and non-empty', () {
      expect(ApiService.baseUrl, isNotEmpty);
      expect(ApiService.baseUrl.startsWith('http'), isTrue);
    });

    test('ApiService token memory caching and clearing', () async {
      await ApiService.saveToken('test_token_xyz');
      expect(await ApiService.getToken(), 'test_token_xyz');

      await ApiService.clearToken();
      expect(await ApiService.getToken(), isNull);
    });

    test('ApiService notifyDataChanged increments refreshNotifier and clears caches', () {
      final initialVal = ApiService.refreshNotifier.value;
      ApiService.notifyDataChanged();
      expect(ApiService.refreshNotifier.value, initialVal + 1);
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
