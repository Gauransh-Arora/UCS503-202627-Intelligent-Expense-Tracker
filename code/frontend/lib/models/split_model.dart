import 'package:intl/intl.dart';

class SplitParticipant {
  final String userId;
  final String name;
  final double amount;
  final double? percentage;
  final bool isPaid;
  final bool isYou;

  const SplitParticipant({
    required this.userId,
    required this.name,
    required this.amount,
    this.percentage,
    this.isPaid = false,
    this.isYou = false,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }
}

class SplitModel {
  final String id;
  final String expenseId;
  final String method; // 'equal', 'percentage', 'custom'
  final List<SplitParticipant> participants;
  final String paidBy;
  final DateTime createdAt;

  const SplitModel({
    required this.id,
    required this.expenseId,
    required this.method,
    required this.participants,
    required this.paidBy,
    required this.createdAt,
  });

  double get totalAmount => participants.fold(0, (sum, p) => sum + p.amount);
}

class DebtModel {
  final String id;
  final String fromUser;
  final String toUser;
  final double amount;
  final String expenseDescription;
  final String expenseId;
  final DateTime dueDate;
  final bool isPaid;

  const DebtModel({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.expenseDescription,
    required this.expenseId,
    required this.dueDate,
    this.isPaid = false,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }
}
