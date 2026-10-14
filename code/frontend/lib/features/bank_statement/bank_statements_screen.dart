import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/bank_statement_model.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Bank Statements List Screen
// ─────────────────────────────────────────────────────────────────────────────

class BankStatementsScreen extends StatefulWidget {
  const BankStatementsScreen({super.key});

  @override
  State<BankStatementsScreen> createState() => _BankStatementsScreenState();
}

class _BankStatementsScreenState extends State<BankStatementsScreen> {
  List<BankStatementSummary> _statements = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.listBankStatements();
      setState(() {
        _statements =
            raw.map(BankStatementSummary.fromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);

    try {
      // 1) Upload
      final statementId = await ApiService.uploadBankStatement(file.path!);

      // 2) Parse
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parsing statement… this may take a moment'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await ApiService.parseBankStatement(statementId);

      // 3) Refresh list
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Statement uploaded and parsed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _delete(BankStatementSummary stmt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Statement',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${stmt.displayName}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteBankStatement(stmt.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: _load))
          else if (_statements.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onUpload: _pickAndUpload, isUploading: _isUploading),
            )
          else ...[
            _buildSummaryBanner(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _StatementCard(
                    statement: _statements[i],
                    onTap: () => _openDetail(_statements[i].id),
                    onDelete: () => _delete(_statements[i]),
                  ),
                  childCount: _statements.length,
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _statements.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _pickAndUpload,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_isUploading ? 'Uploading…' : 'Upload Statement'),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.surfaceCard,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: const Text(
          'Bank Statements',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF3FF), AppColors.surfaceCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -10,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                top: 50,
                child: Icon(Icons.account_balance_rounded,
                    size: 60, color: AppColors.primary.withOpacity(0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final totalDebits =
        _statements.fold<double>(0, (s, e) => s + e.totalDebits);
    final totalCredits =
        _statements.fold<double>(0, (s, e) => s + e.totalCredits);
    final fmt = NumberFormat.compactCurrency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 1);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'Total Debits',
                  value: fmt.format(totalDebits),
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFFFB3B3),
                ),
              ),
              Container(
                  width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              Expanded(
                child: _BannerStat(
                  label: 'Total Credits',
                  value: fmt.format(totalCredits),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFFB3FFD1),
                ),
              ),
              Container(
                  width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              Expanded(
                child: _BannerStat(
                  label: 'Statements',
                  value: '${_statements.length}',
                  icon: Icons.description_rounded,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BankStatementDetailScreen(statementId: id)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Statement Card
// ─────────────────────────────────────────────────────────────────────────────

class _StatementCard extends StatelessWidget {
  final BankStatementSummary statement;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _StatementCard({
    required this.statement,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat.compactCurrency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 1);
    final statusColor = _statusColor(statement.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statement.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (statement.accountNumber != null)
                            Text(
                              'A/C ${statement.accountNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statement.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.textTertiary, size: 20),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Transactions',
                        value: '${statement.totalTransactions}',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Debits',
                        value: fmtCurrency.format(statement.totalDebits),
                        icon: Icons.arrow_upward_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Credits',
                        value: fmtCurrency.format(statement.totalCredits),
                        icon: Icons.arrow_downward_rounded,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                if (statement.periodFrom != null ||
                    statement.periodTo != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        statement.periodLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'parsed':
        return AppColors.success;
      case 'parsing':
        return AppColors.warning;
      case 'failed':
        return AppColors.danger;
      default:
        return AppColors.textTertiary;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class BankStatementDetailScreen extends StatefulWidget {
  final String statementId;

  const BankStatementDetailScreen({super.key, required this.statementId});

  @override
  State<BankStatementDetailScreen> createState() =>
      _BankStatementDetailScreenState();
}

class _BankStatementDetailScreenState
    extends State<BankStatementDetailScreen> {
  BankStatementDetail? _detail;
  bool _isLoading = true;
  String? _error;

  String _filter = 'all'; // 'all' | 'debit' | 'credit'
  String _searchQuery = '';
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getBankStatement(widget.statementId);
      setState(() {
        _detail = BankStatementDetail.fromJson(raw);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<BankStatementRow> get _filteredRows {
    if (_detail == null) return [];
    var rows = _detail!.rows;

    if (_filter == 'debit') {
      rows = rows.where((r) => r.isDebit).toList();
    } else if (_filter == 'credit') {
      rows = rows.where((r) => r.isCredit).toList();
    }

    if (_searchQuery.isNotEmpty) {
      rows = rows
          .where((r) =>
              r.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != null) {
      rows = rows.where((r) => r.category == _selectedCategory).toList();
    }

    return rows;
  }

  List<String> get _allCategories {
    if (_detail == null) return [];
    final cats = _detail!.rows
        .map((r) => r.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statement Detail')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    final d = _detail!;
    final filtered = _filteredRows;

    // Category spend breakdown for the chart section
    final Map<String, double> categorySpend = {};
    for (final row in d.rows) {
      if (row.isDebit) {
        final cat = row.category ?? 'Others';
        categorySpend[cat] = (categorySpend[cat] ?? 0) + row.amount;
      }
    }
    final sortedCats = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildDetailAppBar(d),
          SliverToBoxAdapter(child: _buildStatCards(d)),
          if (sortedCats.isNotEmpty)
            SliverToBoxAdapter(child: _buildCategoryBreakdown(sortedCats, d)),
          SliverToBoxAdapter(child: _buildFilters()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: filtered.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No transactions match your filters.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TransactionRow(row: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailAppBar(BankStatementDetail d) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (d.accountNumber != null)
              Text(
                'A/C ${d.accountNumber}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w400),
              ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Icon(Icons.account_balance_rounded,
                  size: 80, color: Colors.white.withOpacity(0.15)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(BankStatementDetail d) {
    final fmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Transactions',
              value: '${d.totalTransactions}',
              icon: Icons.receipt_long_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Total Debits',
              value: fmt.format(d.totalDebits),
              icon: Icons.arrow_upward_rounded,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Total Credits',
              value: fmt.format(d.totalCredits),
              icon: Icons.arrow_downward_rounded,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      List<MapEntry<String, double>> sortedCats, BankStatementDetail d) {
    final fmt = NumberFormat.compactCurrency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final maxVal = sortedCats.first.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Category',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ...sortedCats.take(6).map((entry) {
              final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
              final color = AppColors.categoryColor(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 8,
                          backgroundColor: color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fmt.format(entry.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Search
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Debit / Credit toggle
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Debits',
                selected: _filter == 'debit',
                color: AppColors.danger,
                onTap: () => setState(() => _filter = 'debit'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Credits',
                selected: _filter == 'credit',
                color: AppColors.success,
                onTap: () => setState(() => _filter = 'credit'),
              ),
              const Spacer(),
              // Category filter dropdown
              if (_allCategories.isNotEmpty)
                DropdownButton<String?>(
                  value: _selectedCategory,
                  hint: const Text('Category',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.filter_list_rounded,
                      color: AppColors.primary, size: 18),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories',
                          style: TextStyle(fontSize: 12)),
                    ),
                    ..._allCategories.map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Transaction Row widget
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final BankStatementRow row;

  const _TransactionRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final isDebit = row.isDebit;
    final amountColor = isDebit ? AppColors.danger : AppColors.success;
    final amountPrefix = isDebit ? '- ' : '+ ';
    final catColor = AppColors.categoryColor(row.category ?? 'Others');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            AppColors.categoryIcon(row.category ?? 'Others'),
            color: catColor,
            size: 20,
          ),
        ),
        title: Text(
          row.description,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              row.formattedDate,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
            if (row.category != null) ...[
              const Text(' · ',
                  style: TextStyle(color: AppColors.textTertiary)),
              Text(
                row.category!,
                style: TextStyle(
                    fontSize: 11,
                    color: catColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${row.formattedAmount}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: amountColor,
              ),
            ),
            if (row.balance != null)
              Text(
                'Bal: ${NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(row.balance)}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BannerStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: color),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  final bool isUploading;

  const _EmptyState({required this.onUpload, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Bank Statements Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a PDF or CSV bank statement\nto automatically parse your transactions.',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: isUploading ? null : onUpload,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isUploading ? 'Uploading…' : 'Upload Statement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
