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

// ─── Backend Split & Friend Models ──────────────────────────────────────────

class FriendModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  const FriendModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Friend',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
      };
}

class FriendBalanceItemModel {
  final String friendName;
  final String? friendId;
  final double netBalance;
  final double totalOwedByFriend;
  final double totalSettledByFriend;
  final double totalOwedByUser;
  final double totalSettledByUser;
  final String status; // 'owes_you', 'you_owe', 'settled'

  const FriendBalanceItemModel({
    required this.friendName,
    this.friendId,
    required this.netBalance,
    required this.totalOwedByFriend,
    required this.totalSettledByFriend,
    required this.totalOwedByUser,
    required this.totalSettledByUser,
    required this.status,
  });

  factory FriendBalanceItemModel.fromJson(Map<String, dynamic> json) {
    return FriendBalanceItemModel(
      friendName: json['friend_name'] as String? ?? 'Contact',
      friendId: json['friend_id'] as String?,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0.0,
      totalOwedByFriend: (json['total_owed_by_friend'] as num?)?.toDouble() ?? 0.0,
      totalSettledByFriend: (json['total_settled_by_friend'] as num?)?.toDouble() ?? 0.0,
      totalOwedByUser: (json['total_owed_by_user'] as num?)?.toDouble() ?? 0.0,
      totalSettledByUser: (json['total_settled_by_user'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'settled',
    );
  }

  String get formattedNetBalance {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(netBalance.abs());
  }
}

class UserBalanceModel {
  final double totalOwedToUser;
  final double totalUserOwes;
  final double netBalance;
  final List<FriendBalanceItemModel> friendBalances;

  const UserBalanceModel({
    required this.totalOwedToUser,
    required this.totalUserOwes,
    required this.netBalance,
    required this.friendBalances,
  });

  factory UserBalanceModel.fromJson(Map<String, dynamic> json) {
    final list = json['friend_balances'] as List? ?? [];
    return UserBalanceModel(
      totalOwedToUser: (json['total_owed_to_user'] as num?)?.toDouble() ?? 0.0,
      totalUserOwes: (json['total_user_owes'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0.0,
      friendBalances: list
          .map((e) => FriendBalanceItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FriendLedgerItemModel {
  final String id;
  final String type; // 'split' or 'settlement'
  final DateTime date;
  final String description;
  final double amount;
  final String role; // 'borrowed', 'lent', 'settled'

  const FriendLedgerItemModel({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.amount,
    required this.role,
  });

  factory FriendLedgerItemModel.fromJson(Map<String, dynamic> json) {
    return FriendLedgerItemModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'split',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      role: json['role'] as String? ?? '',
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }
}

class FriendLedgerModel {
  final FriendModel friend;
  final double currentBalance;
  final String status;
  final List<FriendLedgerItemModel> ledgerEntries;

  const FriendLedgerModel({
    required this.friend,
    required this.currentBalance,
    required this.status,
    required this.ledgerEntries,
  });

  factory FriendLedgerModel.fromJson(Map<String, dynamic> json) {
    final list = json['ledger_entries'] as List? ?? [];
    return FriendLedgerModel(
      friend: FriendModel.fromJson(json['friend'] as Map<String, dynamic>? ?? {}),
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'settled',
      ledgerEntries: list
          .map((e) => FriendLedgerItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SettlementItemModel {
  final String id;
  final String? splitId;
  final String payerName;
  final String payeeName;
  final double amount;
  final String status;
  final DateTime? settledAt;
  final DateTime createdAt;

  const SettlementItemModel({
    required this.id,
    this.splitId,
    required this.payerName,
    required this.payeeName,
    required this.amount,
    required this.status,
    this.settledAt,
    required this.createdAt,
  });

  factory SettlementItemModel.fromJson(Map<String, dynamic> json) {
    return SettlementItemModel(
      id: json['id'] as String? ?? '',
      splitId: json['split_id'] as String?,
      payerName: json['payer_name'] as String? ?? '',
      payeeName: json['payee_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'settled',
      settledAt: json['settled_at'] != null ? DateTime.tryParse(json['settled_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }
}

class SplitItemModel {
  final String id;
  final String title;
  final double totalAmount;
  final String currency;
  final String splitType;
  final String? description;
  final List<ParticipantItemModel> participants;
  final DateTime createdAt;

  const SplitItemModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.currency,
    required this.splitType,
    this.description,
    required this.participants,
    required this.createdAt,
  });

  factory SplitItemModel.fromJson(Map<String, dynamic> json) {
    final list = json['participants'] as List? ?? [];
    return SplitItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Expense Split',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      splitType: json['split_type'] as String? ?? 'equal',
      description: json['description'] as String?,
      participants: list
          .map((e) => ParticipantItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ParticipantItemModel {
  final String id;
  final String participantName;
  final double amountOwed;
  final double? percentage;
  final bool isPayer;

  const ParticipantItemModel({
    required this.id,
    required this.participantName,
    required this.amountOwed,
    this.percentage,
    required this.isPayer,
  });

  factory ParticipantItemModel.fromJson(Map<String, dynamic> json) {
    return ParticipantItemModel(
      id: json['id'] as String? ?? '',
      participantName: json['participant_name'] as String? ?? '',
      amountOwed: (json['amount_owed'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      isPayer: json['is_payer'] as bool? ?? false,
    );
  }
}
