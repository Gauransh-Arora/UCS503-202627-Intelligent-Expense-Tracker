import 'package:intl/intl.dart';
import '../core/utils/num_parser.dart';

class ExpenseItemModel {
  final String id;
  final String name;
  final int quantity;
  final double price;

  const ExpenseItemModel({
    required this.id,
    required this.name,
    this.quantity = 1,
    required this.price,
  });

  double get total => quantity * price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
      };

  factory ExpenseItemModel.fromJson(Map<String, dynamic> json) =>
      ExpenseItemModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['item_name']?.toString() ?? 'Item',
        quantity: asInt(json['quantity'], 1),
        price: asDouble(json['price'] ?? json['unit_price'] ?? json['total_price']),
      );

  factory ExpenseItemModel.fromJsonBackend(Map<String, dynamic> json) =>
      ExpenseItemModel(
        id: json['id']?.toString() ?? '',
        name: json['item_name']?.toString() ?? json['name']?.toString() ?? 'Item',
        quantity: asInt(json['quantity'], 1),
        price: asDouble(json['unit_price'] ?? json['total_price']),
      );
}

class ExpenseModel {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? categoryId;
  final String paymentMethod;
  final List<ExpenseItemModel> items;
  final String? source; // 'manual', 'ocr_receipt', 'ocr_upi', 'bank_statement'
  final String? notes;
  final bool isRecurring;
  final String? splitId;

  const ExpenseModel({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.categoryId,
    required this.paymentMethod,
    this.items = const [],
    this.source = 'manual',
    this.notes,
    this.isRecurring = false,
    this.splitId,
  });

  static String parseCategory(dynamic category, [dynamic categoryName]) {
    if (categoryName != null) {
      final name = categoryName.toString().trim();
      if (name.isNotEmpty && name != 'null') return name;
    }
    if (category is Map) {
      final name = category['name']?.toString().trim();
      if (name != null && name.isNotEmpty && name != 'null') return name;
    }
    if (category != null) {
      final str = category.toString().trim();
      if (str.isNotEmpty && str != 'null' && !str.startsWith('{') && !str.startsWith('Instance of')) {
        return str;
      }
    }
    return 'Uncategorized';
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String get relativeDate {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('dd MMM').format(date);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        if (categoryId != null) 'category_id': categoryId,
        'paymentMethod': paymentMethod,
        'items': items.map((e) => e.toJson()).toList(),
        'source': source,
        'notes': notes,
        'isRecurring': isRecurring,
        'splitId': splitId,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id']?.toString() ?? '',
        merchant: json['merchant']?.toString() ?? json['merchant_name']?.toString() ?? 'Unknown Merchant',
        amount: asDouble(json['amount']),
        date: DateTime.tryParse(json['date']?.toString() ?? json['transaction_date']?.toString() ?? '') ?? DateTime.now(),
        category: parseCategory(json['category'], json['category_name']),
        categoryId: json['category_id']?.toString() ?? (json['category'] is Map ? json['category']['id']?.toString() : null),
        paymentMethod: json['paymentMethod']?.toString() ?? json['payment_method']?.toString() ?? 'UPI',
        items: (json['items'] as List? ?? [])
            .map((e) => ExpenseItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: json['source']?.toString(),
        notes: json['notes']?.toString() ?? json['description']?.toString(),
        isRecurring: json['isRecurring'] == true || json['is_recurring'] == true,
        splitId: json['splitId']?.toString(),
      );

  factory ExpenseModel.fromJsonBackend(Map<String, dynamic> json) => ExpenseModel(
        id: json['id']?.toString() ?? '',
        merchant: json['merchant_name']?.toString() ?? json['merchant']?.toString() ?? 'Unknown Merchant',
        amount: asDouble(json['amount']),
        date: DateTime.tryParse(json['transaction_date']?.toString() ?? json['date']?.toString() ?? '') ?? DateTime.now(),
        category: parseCategory(json['category'], json['category_name']),
        categoryId: json['category_id']?.toString() ?? (json['category'] is Map ? json['category']['id']?.toString() : null),
        paymentMethod: json['payment_method']?.toString() ?? 'Unknown',
        items: (json['items'] as List? ?? [])
            .map((e) => ExpenseItemModel.fromJsonBackend(e as Map<String, dynamic>))
            .toList(),
        source: json['source']?.toString() ?? 'manual',
        notes: json['description']?.toString() ?? json['notes']?.toString(),
        isRecurring: json['is_recurring'] == true || json['isRecurring'] == true,
      );

  ExpenseModel copyWith({
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
    String? categoryId,
    String? paymentMethod,
    List<ExpenseItemModel>? items,
    String? source,
    String? notes,
  }) {
    return ExpenseModel(
      id: id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      isRecurring: isRecurring,
      splitId: splitId,
    );
  }
}
