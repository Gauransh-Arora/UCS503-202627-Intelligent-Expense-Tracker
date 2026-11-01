import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
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
        _statements = raw.map(BankStatementSummary.fromJson).toList();
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
      allowMultiple: false,
    );
    if (result.isEmpty) return;

    final file = result.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);

    try {
      // 1) Upload
      final statementId = await ApiService.uploadBankStatement(file.path!);

      // 2) Parse
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parsing statement...'),
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
            content: Text('Statement uploaded and parsed successfully'),
            backgroundColor: AppColors.credit,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.debit,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        title: const Text(
          'Delete Statement',
          style: TextStyle(fontFamily: AppTheme.fontSans, fontSize: 16),
        ),
        content: Text(
          'Delete "${stmt.displayName}" and associated statement entries?',
          style: const TextStyle(
            fontFamily: AppTheme.fontSans,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.debit),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteBankStatement(stmt.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Statement deleted')));
      }
    } catch (e) {
      if (mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.debit,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUpload,
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        icon: _isUploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file_rounded, size: 20),
        label: Text(
          _isUploading ? 'Uploading...' : 'Import Statement',
          style: const TextStyle(
            fontFamily: AppTheme.fontSans,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_statements.isNotEmpty) _buildSummaryBanner(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Text(
        'Bank Statements',
        style: TextStyle(
          fontFamily: AppTheme.fontSans,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final totalDebits = _statements.fold<double>(
      0,
      (s, e) => s + e.totalDebits,
    );
    final totalCredits = _statements.fold<double>(
      0,
      (s, e) => s + e.totalCredits,
    );
    final fmt = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'Total Debits',
                  value: fmt.format(totalDebits),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.debit,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _BannerStat(
                  label: 'Total Credits',
                  value: fmt.format(totalCredits),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.credit,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _BannerStat(
                  label: 'Statements',
                  value: '${_statements.length}',
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.ink,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppColors.debit,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_statements.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Statements Imported',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload PDF or CSV statements to automatically parse transactions into your ledger.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final stmt = _statements[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatementCard(
              statement: stmt,
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => BankStatementDetailScreen(
                        statementId: stmt.id,
                        fileName: stmt.displayName,
                      ),
                    ),
                  )
                  .then((_) => _load()),
              onDelete: () => _delete(stmt),
            ),
          );
        }, childCount: _statements.length),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontSans,
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

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
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isPdf = statement.originalFilename.toLowerCase().endsWith('.pdf');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(
                  isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.table_chart_outlined,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statement.displayName,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${statement.totalTransactions} txns',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      Text(
                        statement.status.isNotEmpty
                            ? (statement.status[0].toUpperCase() +
                                statement.status.substring(1).toLowerCase())
                            : statement.status,
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statement.status.toLowerCase() == 'parsed'
                              ? AppColors.credit
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(statement.totalDebits),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.debit,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM').format(statement.createdAt),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textTertiary,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bank Statement Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class BankStatementDetailScreen extends StatefulWidget {
  final String statementId;
  final String fileName;

  const BankStatementDetailScreen({
    super.key,
    required this.statementId,
    required this.fileName,
  });

  @override
  State<BankStatementDetailScreen> createState() =>
      _BankStatementDetailScreenState();
}

class _BankStatementDetailScreenState extends State<BankStatementDetailScreen> {
  BankStatementDetail? _detail;
  bool _isLoading = true;
  String? _error;
  String _selectedTab = 'all';

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

  bool _isMerging = false;

  Future<void> _mergeEntries() async {
    setState(() => _isMerging = true);
    try {
      final res = await ApiService.mergeBankStatement(widget.statementId);
      final merged = res['merged_count'] ?? 0;
      final skipped = res['skipped_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Merged $merged verified transactions ($skipped skipped)',
            ),
            backgroundColor: AppColors.credit,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
            backgroundColor: AppColors.debit,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            tooltip: 'Merge into ledger',
            icon: _isMerging
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.ink,
                    ),
                  )
                : const Icon(Icons.call_merge_rounded, size: 20),
            onPressed: _isMerging ? null : _mergeEntries,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ink,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.debit,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final d = _detail!;
    final filtered = _getFilteredRows(d);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        _buildStatCards(d),
        const SizedBox(height: 16),
        _buildTabs(d),
        const SizedBox(height: 12),
        ...filtered.map((row) => _buildRowTile(row)),
      ],
    );
  }

  Widget _buildStatCards(BankStatementDetail d) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
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
                const SizedBox(height: 4),
                Text(
                  fmt.format(d.totalDebits),
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
          Container(width: 1, height: 32, color: AppColors.border),
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
                const SizedBox(height: 4),
                Text(
                  fmt.format(d.totalCredits),
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
    );
  }

  Widget _buildTabs(BankStatementDetail d) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TabChip(
            label: 'All (${d.rows.length})',
            isSelected: _selectedTab == 'all',
            onTap: () => setState(() => _selectedTab = 'all'),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Debits (${d.rows.where((r) => r.isDebit).length})',
            isSelected: _selectedTab == 'debits',
            onTap: () => setState(() => _selectedTab = 'debits'),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Credits (${d.rows.where((r) => !r.isDebit).length})',
            isSelected: _selectedTab == 'credits',
            onTap: () => setState(() => _selectedTab = 'credits'),
          ),
        ],
      ),
    );
  }

  List<BankStatementRow> _getFilteredRows(BankStatementDetail d) {
    switch (_selectedTab) {
      case 'debits':
        return d.rows.where((r) => r.isDebit).toList();
      case 'credits':
        return d.rows.where((r) => !r.isDebit).toList();
      default:
        return d.rows;
    }
  }

  Widget _buildRowTile(BankStatementRow row) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.description,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.formattedDate} · ${row.category ?? "General"}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            (row.isDebit ? '− ' : '+ ') + fmt.format(row.amount),
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: row.isDebit ? AppColors.debit : AppColors.credit,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      onSelected: (_) => onTap(),
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        side: BorderSide(color: isSelected ? AppColors.ink : AppColors.border),
      ),
    );
  }
}
