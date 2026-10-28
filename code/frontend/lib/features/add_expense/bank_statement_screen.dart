import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
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

    // Handle UPI strings: UPI/123456/MERCHANT/BANK -> MERCHANT
    if (trimmed.toUpperCase().startsWith('UPI/') || trimmed.toUpperCase().startsWith('UPI-')) {
      final parts = trimmed.split(RegExp(r'[/|-]'));
      if (parts.length >= 3) {
        final cand = parts[2].trim();
        if (cand.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cand)) {
          return cand;
        }
      }
    }
    // Clean up excessive whitespace
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
          content: Text('Could not pick file: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _process() async {
    if (_filePath == null) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Uploading statement...';
      _state = _BankState.processing;
    });

    try {
      // Step 1: Upload statement file
      final statementId = await ApiService.uploadBankStatement(_filePath!);

      if (!mounted) return;
      setState(() {
        _processingMessage = 'Extracting transactions with AI...';
      });

      // Step 2: Parse statement
      final parsed = await ApiService.parseBankStatement(statementId);

      _bankName = parsed['bank_name'] as String?;
      _periodFrom = parsed['statement_period_from'] as String?;
      _periodTo = parsed['statement_period_to'] as String?;
      _totalDebits = (parsed['total_debits'] as num?)?.toDouble() ?? 0.0;
      _totalCredits = (parsed['total_credits'] as num?)?.toDouble() ?? 0.0;

      final rawRows = parsed['parsed_rows'] as List<dynamic>? ?? [];
      final List<_StatementItem> items = [];

      for (final r in rawRows) {
        final row = r as Map<String, dynamic>;
        final debit = (row['debit'] as num?)?.toDouble();
        final credit = (row['credit'] as num?)?.toDouble();
        final isDebit = (debit != null && debit > 0);
        final amount = isDebit ? debit : (credit ?? 0.0);
        final desc = row['description'] as String? ?? '';
        final cat = row['category'] as String? ?? 'Other';
        final isVerified = cat != 'Unrecognised' && cat != 'Uncategorised' && cat.isNotEmpty;

        items.add(
          _StatementItem(
            date: row['date'] as String? ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
            merchant: _cleanMerchant(desc),
            amount: amount,
            isDebit: isDebit,
            category: cat,
            categoryId: _matchCategoryId(cat),
            isSelected: isDebit, // Default to selecting debit expenses
            isVerified: isVerified,
            originalDescription: desc,
          ),
        );
      }

      if (!mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions found in this statement. Please check the file format.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      setState(() {
        _transactions = items;
        _isProcessing = false;
        _state = _BankState.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _state = _BankState.uploaded;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process statement: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _importSelected() async {
    final selected = _transactions.where((t) => t.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one transaction to import')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selected.length;
    });

    int imported = 0;
    int failed = 0;

    for (int i = 0; i < selected.length; i++) {
      if (!mounted) return;
      final tx = selected[i];
      setState(() => _importProgress = i + 1);

      try {
        await ApiService.createTransaction({
          'merchant_name': tx.merchant.trim().isNotEmpty ? tx.merchant.trim() : 'Bank Transaction',
          'amount': tx.amount > 0 ? tx.amount : 1.0,
          'currency': 'INR',
          'transaction_date': tx.date.isNotEmpty ? tx.date : DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'payment_method': 'bank',
          'description': 'Imported from ${_fileName ?? "bank statement"}',
          if (tx.categoryId != null) 'category_id': tx.categoryId,
        });
        imported++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _isImporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$imported transactions imported successfully!'
              : '$imported imported ($failed failed).',
        ),
        backgroundColor: failed == 0 ? AppColors.success : AppColors.warning,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Transaction', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: merchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                  label: Text(c),
                  selected: isCurrent,
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _buildBody(),
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
        // Illustration banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Import Bank Statement',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your PDF or CSV bank statement. Our AI will automatically parse and categorize every transaction for you.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('Choose File Format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _FormatButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF Statement',
                isSelected: _isPdf,
                onTap: () => _pickFile(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatButton(
                icon: Icons.table_chart_rounded,
                label: 'CSV / Excel File',
                isSelected: !_isPdf,
                onTap: () => _pickFile(false),
              ),
            ),
          ],
        ),

        if (_fileName != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fileSizeBytes != null
                            ? '${_formatFileSize(_fileSizeBytes!)} • Ready to process'
                            : 'Ready to process',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
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
          const SizedBox(height: 24),
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Extracting dates, descriptions, categories & amounts...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            PrimaryButton(
              label: 'Upload & Process with AI',
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              isLoading: _isProcessing,
              onPressed: _process,
            ),
        ],

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_outlined, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your bank statement is processed securely on your local server. We do not store or sell your personal banking credentials.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.info),
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
    final recognizedCount = _transactions.where((t) => t.isVerified).length;
    final selectedCount = _transactions.where((t) => t.isSelected).length;
    final filtered = _filteredTransactions;

    String periodLabel = 'Statement Transactions';
    if (_periodFrom != null && _periodTo != null) {
      periodLabel = '${_formatDate(_periodFrom!)} – ${_formatDate(_periodTo!)}';
    }

    return Column(
      key: const ValueKey('review_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bankName ?? _fileName ?? 'Statement Parsed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          periodLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_transactions.length} Found',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$recognizedCount recognized • $unverifiedCount need review',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  if (_totalDebits > 0 || _totalCredits > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_totalDebits > 0)
                          Text(
                            '₹${NumberFormat('#,##,###').format(_totalDebits)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const Text(
                          'Total Debits',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (_totalCredits > 0)
                          Text(
                            '+₹${NumberFormat('#,##,###').format(_totalCredits)} credits',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All (${_transactions.length})', _FilterTab.all),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Expenses (${_transactions.where((t) => t.isDebit).length})',
                _FilterTab.debits,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Income / Deposits (${_transactions.where((t) => !t.isDebit).length})',
                _FilterTab.credits,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selection controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected: $selectedCount of ${_transactions.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                  child: const Text('Select All', style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final t in filtered) {
                        t.isSelected = false;
                      }
                    });
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Transactions list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No transactions match this filter', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final tx = filtered[index];
              return _buildTransactionCard(tx);
            },
          ),

        const SizedBox(height: 24),

        if (unverifiedCount > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$unverifiedCount transaction(s) have unverified categories. Tap any card to edit its merchant name or category before importing.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        PrimaryButton(
          label: _isImporting
              ? 'Importing $_importProgress of $_importTotal...'
              : 'Import Selected ($selectedCount)',
          icon: const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
          isLoading: _isImporting,
          onPressed: _isImporting || selectedCount == 0 ? null : _importSelected,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            onPressed: () => setState(() {
              _state = _BankState.uploaded;
              _transactions.clear();
            }),
            label: const Text('Upload Different Statement'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, _FilterTab tab) {
    final isSelected = _selectedFilter == tab;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onSelected: (_) => setState(() => _selectedFilter = tab),
    );
  }

  Widget _buildTransactionCard(_StatementItem tx) {
    return InkWell(
      onTap: () => _editTransaction(tx),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tx.isSelected
                ? (tx.isVerified ? AppColors.border : AppColors.warning)
                : AppColors.border.withValues(alpha: 0.4),
            width: tx.isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: tx.isSelected,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                setState(() => tx.isSelected = val ?? false);
              },
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tx.isVerified ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                tx.isVerified ? Icons.check_circle_outline : Icons.help_outline_rounded,
                color: tx.isVerified ? AppColors.success : AppColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatDate(tx.date),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const Text('  •  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.category,
                          style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${tx.isDebit ? "-" : "+"}₹${tx.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: tx.isDebit ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
