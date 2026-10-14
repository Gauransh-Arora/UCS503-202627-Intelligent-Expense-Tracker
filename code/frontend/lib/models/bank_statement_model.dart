import 'package:intl/intl.dart';

/// A single parsed row from a bank statement.
class BankStatementRow {
  final String date;
  final String description;
  final double? debit;
  final double? credit;
  final double? balance;
  final String? category;

  const BankStatementRow({
    required this.date,
    required this.description,
    this.debit,
    this.credit,
    this.balance,
    this.category,
  });

  factory BankStatementRow.fromJson(Map<String, dynamic> json) =>
      BankStatementRow(
        date: json['date'] as String? ?? '',
        description: json['description'] as String? ?? '',
        debit: (json['debit'] as num?)?.toDouble(),
        credit: (json['credit'] as num?)?.toDouble(),
        balance: (json['balance'] as num?)?.toDouble(),
        category: json['category'] as String?,
      );

  bool get isDebit => (debit ?? 0) > 0;
  bool get isCredit => (credit ?? 0) > 0;
  double get amount => isDebit ? (debit ?? 0) : (credit ?? 0);

  String get formattedDate {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  String get formattedAmount {
    final formatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }
}

/// Lightweight summary used in list views.
class BankStatementSummary {
  final String id;
  final String originalFilename;
  final String? bankName;
  final String? accountNumber;
  final String? periodFrom;
  final String? periodTo;
  final String status;
  final int totalTransactions;
  final double totalDebits;
  final double totalCredits;
  final DateTime createdAt;

  const BankStatementSummary({
    required this.id,
    required this.originalFilename,
    this.bankName,
    this.accountNumber,
    this.periodFrom,
    this.periodTo,
    required this.status,
    required this.totalTransactions,
    required this.totalDebits,
    required this.totalCredits,
    required this.createdAt,
  });

  factory BankStatementSummary.fromJson(Map<String, dynamic> json) =>
      BankStatementSummary(
        id: json['id'] as String,
        originalFilename: json['original_filename'] as String? ?? 'Statement',
        bankName: json['bank_name'] as String?,
        accountNumber: json['account_number'] as String?,
        periodFrom: json['statement_period_from'] as String?,
        periodTo: json['statement_period_to'] as String?,
        status: json['status'] as String? ?? 'unknown',
        totalTransactions: json['total_transactions'] as int? ?? 0,
        totalDebits: (json['total_debits'] as num?)?.toDouble() ?? 0,
        totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  String get displayName =>
      bankName?.isNotEmpty == true ? bankName! : originalFilename;

  String get periodLabel {
    if (periodFrom == null && periodTo == null) return 'Period unknown';
    String fmt(String? d) {
      if (d == null) return '?';
      try {
        return DateFormat('dd MMM yy').format(DateTime.parse(d));
      } catch (_) {
        return d;
      }
    }
    return '${fmt(periodFrom)} – ${fmt(periodTo)}';
  }
}

/// Full statement detail including all parsed rows.
class BankStatementDetail extends BankStatementSummary {
  final List<BankStatementRow> rows;
  final String? errorMessage;

  const BankStatementDetail({
    required super.id,
    required super.originalFilename,
    super.bankName,
    super.accountNumber,
    super.periodFrom,
    super.periodTo,
    required super.status,
    required super.totalTransactions,
    required super.totalDebits,
    required super.totalCredits,
    required super.createdAt,
    required this.rows,
    this.errorMessage,
  });

  factory BankStatementDetail.fromJson(Map<String, dynamic> json) {
    final rawRows = json['parsed_rows'] as List<dynamic>? ?? [];
    return BankStatementDetail(
      id: json['id'] as String,
      originalFilename: json['original_filename'] as String? ?? 'Statement',
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      periodFrom: json['statement_period_from'] as String?,
      periodTo: json['statement_period_to'] as String?,
      status: json['status'] as String? ?? 'unknown',
      totalTransactions: json['total_transactions'] as int? ?? 0,
      totalDebits: (json['total_debits'] as num?)?.toDouble() ?? 0,
      totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      rows: rawRows
          .map((r) => BankStatementRow.fromJson(r as Map<String, dynamic>))
          .toList(),
      errorMessage: json['error_message'] as String?,
    );
  }
}
