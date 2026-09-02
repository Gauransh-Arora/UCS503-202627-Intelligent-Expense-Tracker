import 'package:intl/intl.dart';

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
        id: json['id'],
        name: json['name'],
        quantity: json['quantity'] ?? 1,
        price: (json['price'] as num).toDouble(),
      );
}

class ExpenseModel {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
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
    required this.paymentMethod,
    this.items = const [],
    this.source = 'manual',
    this.notes,
    this.isRecurring = false,
    this.splitId,
  });

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
        'paymentMethod': paymentMethod,
        'items': items.map((e) => e.toJson()).toList(),
        'source': source,
        'notes': notes,
        'isRecurring': isRecurring,
        'splitId': splitId,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'],
        merchant: json['merchant'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        category: json['category'],
        paymentMethod: json['paymentMethod'],
        items: (json['items'] as List? ?? [])
            .map((e) => ExpenseItemModel.fromJson(e))
            .toList(),
        source: json['source'],
        notes: json['notes'],
        isRecurring: json['isRecurring'] ?? false,
        splitId: json['splitId'],
      );

  ExpenseModel copyWith({
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      isRecurring: isRecurring,
      splitId: splitId,
    );
  }
}
