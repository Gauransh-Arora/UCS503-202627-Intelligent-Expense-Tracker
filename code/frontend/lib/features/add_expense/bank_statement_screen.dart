import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/num_parser.dart';
import '../../models/category_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({super.key});

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

enum _BankState { initial, uploaded, processing, review }

enum _FilterTab { all, debits, credits }

class _StatementItem {
  String date;
  String merchant;
  double amount;
  bool isDebit;
  String category;
  String? categoryId;
  bool isSelected;
  bool isVerified;
  String originalDescription;

  _StatementItem({
    required this.date,
    required this.merchant,
    required this.amount,
    required this.isDebit,
    required this.category,
    this.categoryId,
    this.isSelected = true,
    this.isVerified = true,
    required this.originalDescription,
  });
}

class _BankStatementScreenState extends State<BankStatementScreen> {
  _BankState _state = _BankState.initial;
  String? _filePath;
  String? _fileName;
  int? _fileSizeBytes;
  bool _isPdf = true;
  String? _statementId;

  bool _isProcessing = false;
  String _processingMessage = 'Uploading statement...';
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;

  // Metadata from parsed statement
  String? _bankName;
  String? _periodFrom;
  String? _periodTo;
  double _totalDebits = 0;
  double _totalCredits = 0;

  List<_StatementItem> _transactions = [];
  List<CategoryModel> _categories = [];
  _FilterTab _selectedFilter = _FilterTab.all;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.getCategories();
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (_) {
      // Categories fallback to default names
    }
  }

  String? _matchCategoryId(String categoryName) {
    if (_categories.isEmpty) return null;
    final clean = categoryName.trim().toLowerCase();
    for (final c in _categories) {
      if (c.name.toLowerCase() == clean ||
          c.name.toLowerCase().contains(clean) ||
          clean.contains(c.name.toLowerCase())) {
        return c.id;
      }
    }
    return null;
  }

  String _cleanMerchant(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Bank Transaction';

    if (trimmed.toUpperCase().startsWith('UPI/') ||
        trimmed.toUpperCase().startsWith('UPI-')) {
      final parts = trimmed.split(RegExp(r'[/|-]'));
      if (parts.length >= 3) {
        final cand = parts[2].trim();
        if (cand.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cand)) {
          return cand;
        }
      }
    }
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _pickFile(bool isPdf) async {
    setState(() => _isPdf = isPdf);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: isPdf ? ['pdf'] : ['csv', 'txt'],
      );

      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) return;

      int? size;
      try {
        size = File(file.path!).lengthSync();
      } catch (_) {}

      setState(() {
        _filePath = file.path;
        _fileName = file.name;
        _fileSizeBytes = size;
        _state = _BankState.uploaded;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: AppColors.debit,
        ),
      );
    }
  }

  void _populateFromParsed(Map<String, dynamic> parsed) {
    _bankName = parsed['bank_name'] as String?;
    _periodFrom = parsed['statement_period_from'] as String?;
    _periodTo = parsed['statement_period_to'] as String?;
    _totalDebits = asDouble(parsed['total_debits']);
    _totalCredits = asDouble(parsed['total_credits']);

    final rawRows = parsed['parsed_rows'] as List<dynamic>? ?? [];
    final List<_StatementItem> items = [];

    for (final r in rawRows) {
      final row = r as Map<String, dynamic>;
      final debit = asDoubleOrNull(row['debit']);
      final credit = asDoubleOrNull(row['credit']);
      final isDebit = (debit != null && debit > 0);
      final amount = isDebit ? debit : (credit ?? 0.0);
      final desc = row['description'] as String? ?? '';
      final cat = row['category'] as String? ?? 'Other';
      final isVerified =
          cat != 'Unrecognised' && cat != 'Uncategorised' && cat.isNotEmpty;

      items.add(
        _StatementItem(
          date:
              row['date'] as String? ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
          merchant: _cleanMerchant(desc),
          amount: amount,
          isDebit: isDebit,
          category: cat.isEmpty ? 'Other' : cat,
          categoryId: _matchCategoryId(cat),
          isSelected: isDebit,
          isVerified: isVerified,
          originalDescription: desc,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _transactions = items;
      _isProcessing = false;
      _state = _BankState.review;
    });
  }

  Future<void> _process() async {
    if (_filePath == null) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Uploading statement...';
      _state = _BankState.processing;
    });

    try {
      final statementId = await ApiService.uploadBankStatement(_filePath!);
      _statementId = statementId;

      if (!mounted) return;
      setState(() {
        _processingMessage = 'Parsing statement transactions...';
      });

      final parsed = await ApiService.parseBankStatement(statementId);
      _populateFromParsed(parsed);
    } catch (e) {
      if (!mounted) return;
      if (_statementId != null) {
        try {
          final detail = await ApiService.getBankStatement(_statementId!, forceRefresh: true);
          if (detail['status'] == 'parsed' && detail['parsed_rows'] != null) {
            _populateFromParsed(detail);
            return;
          }
        } catch (_) {}
      }
      setState(() {
        _isProcessing = false;
        _state = _BankState.uploaded;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Processing failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.debit,
        ),
      );
    }
  }

  Future<void> _importSelected() async {
    final selected = _transactions.where((t) => t.isSelected).toList();
    if (selected.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selected.length;
    });

    final payloadList = selected.map((t) {
      return <String, dynamic>{
        'merchant_name': t.merchant,
        'amount': t.amount > 0 ? t.amount : 1.0,
        'currency': 'INR',
        'transaction_date': t.date,
        'payment_method': 'net_banking',
        'category_name': t.category,
        if (t.categoryId != null) 'category_id': t.categoryId,
        'source': 'bank_statement',
        'description': t.originalDescription,
      };
    }).toList();

    int imported = 0;
    int failed = 0;

    if (_statementId != null) {
      try {
        final res = await ApiService.mergeBankStatement(_statementId!);
        imported = res['merged_count'] ?? selected.length;
      } catch (_) {
        try {
          final results = await ApiService.createBulkTransactions(payloadList);
          imported = results.length;
        } catch (_) {
          for (int i = 0; i < payloadList.length; i++) {
            if (!mounted) return;
            setState(() => _importProgress = i + 1);
            try {
              await ApiService.createTransaction(payloadList[i], notify: false);
              imported++;
            } catch (_) {
              failed++;
            }
          }
          ApiService.notifyDataChanged();
        }
      }
    } else {
      try {
        final results = await ApiService.createBulkTransactions(payloadList);
        imported = results.length;
      } catch (_) {
        for (int i = 0; i < payloadList.length; i++) {
          if (!mounted) return;
          setState(() => _importProgress = i + 1);
          try {
            await ApiService.createTransaction(payloadList[i], notify: false);
            imported++;
          } catch (_) {
            failed++;
          }
        }
        ApiService.notifyDataChanged();
      }
    }

    if (!mounted) return;
    setState(() => _isImporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$imported transactions imported into ledger'
              : '$imported imported ($failed failed)',
        ),
        backgroundColor: failed == 0 ? AppColors.credit : AppColors.warning,
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _editTransaction(_StatementItem item) {
    final merchantCtrl = TextEditingController(text: item.merchant);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        title: const Text(
          'Edit Transaction',
          style: TextStyle(fontFamily: AppTheme.fontSans, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: merchantCtrl,
              decoration: const InputDecoration(labelText: 'Merchant Name'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Category',
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  [
                    'Food & Dining',
                    'Shopping',
                    'Entertainment',
                    'Travel & Transport',
                    'Utilities',
                    'Healthcare',
                    'Other',
                  ].map((c) {
                    final isCurrent = item.category == c;
                    return ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      selected: isCurrent,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: isCurrent ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            item.category = c;
                            item.categoryId = _matchCategoryId(c);
                            item.isVerified = true;
                          });
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.merchant = merchantCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  List<_StatementItem> get _filteredTransactions {
    switch (_selectedFilter) {
      case _FilterTab.all:
        return _transactions;
      case _FilterTab.debits:
        return _transactions.where((t) => t.isDebit).toList();
      case _FilterTab.credits:
        return _transactions.where((t) => !t.isDebit).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _transactions.where((t) => t.isSelected).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Bank Statement'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _buildBody(),
      ),
      bottomNavigationBar: _state == _BankState.review
          ? _buildBottomBar(selectedCount)
          : null,
    );
  }

  Widget _buildBottomBar(int selectedCount) {
    final selectedDebits = _transactions
        .where((t) => t.isSelected && t.isDebit)
        .fold<double>(0, (s, t) => s + t.amount);
    final skippedCredits = _transactions
        .where((t) => !t.isDebit && !t.isSelected)
        .length;

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$selectedCount selected (${fmt.format(selectedDebits)})',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$skippedCredits credit(s) skipped',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: _isImporting
                  ? 'Importing $_importProgress of $_importTotal...'
                  : 'Import $selectedCount Transactions',
              isLoading: _isImporting,
              onPressed: _isImporting || selectedCount == 0
                  ? null
                  : _importSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _BankState.initial:
      case _BankState.uploaded:
      case _BankState.processing:
        return _buildUploadSection();
      case _BankState.review:
        return _buildReviewSection();
    }
  }

  Widget _buildUploadSection() {
    return Column(
      key: const ValueKey('upload_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Import Bank Statement',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload a PDF or CSV statement. Transactions are parsed into ledger entries for verification before merging.',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Supported Formats',
          style: TextStyle(
            fontFamily: AppTheme.fontSans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _FormatTile(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF Statement',
                isSelected: _isPdf,
                onTap: () => _pickFile(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FormatTile(
                icon: Icons.table_chart_outlined,
                label: 'CSV / Excel File',
                isSelected: !_isPdf,
                onTap: () => _pickFile(false),
              ),
            ),
          ],
        ),

        if (_fileName != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (_fileSizeBytes != null)
                        Text(
                          _formatFileSize(_fileSizeBytes!),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: _isProcessing
                      ? null
                      : () => setState(() {
                          _fileName = null;
                          _filePath = null;
                          _fileSizeBytes = null;
                          _state = _BankState.initial;
                        }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _processingMessage,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            PrimaryButton(
              label: 'Process Statement',
              isLoading: _isProcessing,
              onPressed: _process,
            ),
        ],

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Statements are parsed locally on your server. Personal banking credentials are never requested or stored.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    final unverifiedCount = _transactions.where((t) => !t.isVerified).length;
    final selectedCount = _transactions.where((t) => t.isSelected).length;
    final filtered = _filteredTransactions;

    String periodLabel = 'Statement Transactions';
    if (_periodFrom != null && _periodTo != null) {
      periodLabel = '${_formatDate(_periodFrom!)} – ${_formatDate(_periodTo!)}';
    }

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Column(
      key: const ValueKey('review_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statement Summary Block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _bankName ?? _fileName ?? 'Bank Statement',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_transactions.length} rows',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                periodLabel,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DEBITS',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(_totalDebits),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.debit,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.border),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL CREDITS',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(_totalCredits),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.credit,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All (${_transactions.length})', _FilterTab.all),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Debits (${_transactions.where((t) => t.isDebit).length})',
                _FilterTab.debits,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Credits (${_transactions.where((t) => !t.isDebit).length})',
                _FilterTab.credits,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Select All / Clear Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$selectedCount of ${_transactions.length} selected for merge',
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final t in filtered) {
                        t.isSelected = true;
                      }
                    });
                  },
                  child: const Text(
                    'Select all',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final t in filtered) {
                        t.isSelected = false;
                      }
                    });
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Table-like ledger rows
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No transactions in this view',
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, idx) =>
                  const Divider(height: 1, indent: 48),
              itemBuilder: (context, index) {
                final tx = filtered[index];
                return _buildTransactionRow(tx);
              },
            ),
          ),

        if (unverifiedCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '$unverifiedCount transaction(s) have unverified categories. Tap row to edit category or merchant before import.',
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _state = _BankState.uploaded;
              _transactions.clear();
            }),
            child: const Text('Upload a different statement'),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildFilterChip(String label, _FilterTab tab) {
    final isSelected = _selectedFilter == tab;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontSans,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        side: BorderSide(color: isSelected ? AppColors.ink : AppColors.border),
      ),
      onSelected: (_) => setState(() => _selectedFilter = tab),
    );
  }

  Widget _buildTransactionRow(_StatementItem tx) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return InkWell(
      onTap: () => _editTransaction(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: tx.isSelected,
              activeColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              onChanged: (val) {
                setState(() => tx.isSelected = val ?? false);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatDate(tx.date),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${tx.category}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tx.isVerified
                              ? AppColors.textSecondary
                              : AppColors.warning,
                        ),
                      ),
                      if (!tx.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 12,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              (tx.isDebit ? '− ' : '+ ') + fmt.format(tx.amount),
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tx.isDebit ? AppColors.debit : AppColors.credit,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceCard : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
