import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/expense_model.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/empty_state.dart';
import '../../services/api_service.dart';
import 'expense_detail_screen.dart';

abstract class _ListItem {}

class _DateHeaderItem extends _ListItem {
  final String label;
  _DateHeaderItem(this.label);
}

class _ExpenseItem extends _ListItem {
  final ExpenseModel expense;
  _ExpenseItem(this.expense);
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'newest';

  bool _isLoading = true;
  String? _error;
  List<ExpenseModel> _allExpenses = [];

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
    ApiService.refreshNotifier.addListener(_onRefreshNotified);
  }

  void _onRefreshNotified() {
    if (mounted) {
      _fetchExpenses();
    }
  }

  @override
  void dispose() {
    ApiService.refreshNotifier.removeListener(_onRefreshNotified);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExpenses({bool forceRefresh = false}) async {
    try {
      final expenses = await ApiService.getTransactions(
        limit: 100,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _allExpenses = expenses;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_ListItem> _buildListItems() {
    var list = _allExpenses.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (e) =>
                e.merchant.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_selectedCategory != null) {
      final cat = _selectedCategory!.toLowerCase();
      list = list.where((e) => e.category.toLowerCase() == cat).toList();
    }

    switch (_sortBy) {
      case 'newest':
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'oldest':
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'highest':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'lowest':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    final grouped = <String, List<ExpenseModel>>{};
    for (final e in list) {
      final label = e.relativeDate;
      grouped.putIfAbsent(label, () => []).add(e);
    }

    final items = <_ListItem>[];
    for (final entry in grouped.entries) {
      items.add(_DateHeaderItem(entry.key));
      for (final expense in entry.value) {
        items.add(_ExpenseItem(expense));
      }
    }

    return items;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedCategory: _selectedCategory,
        sortBy: _sortBy,
        onApply: (cat, sort) {
          setState(() {
            _selectedCategory = cat;
            _sortBy = sort;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listItems = _buildListItems();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction Ledger'),
        actions: [
          IconButton(
            tooltip: 'Filter transactions',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LucideIcons.slidersHorizontal, size: 20),
                if (_selectedCategory != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.ink),
                ),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Unable to load transactions',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!.replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _fetchExpenses(forceRefresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search merchant or category...',
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSmall,
                          ),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSmall,
                          ),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ),

                // Active filters
                if (_selectedCategory != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentMuted,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSmall,
                            ),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCategory!,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = null),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expense list (dense ledger view)
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.ink,
                    onRefresh: () => _fetchExpenses(forceRefresh: true),
                    child: listItems.isEmpty
                        ? EmptyState(
                            icon: LucideIcons.receipt,
                            title: 'No transactions found',
                            description: _searchQuery.isNotEmpty
                                ? 'No matches for "$_searchQuery"'
                                : 'No expenses recorded matching the selected filter.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: listItems.length,
                            itemBuilder: (context, index) {
                              final item = listItems[index];
                              if (item is _DateHeaderItem) {
                                return _DateHeader(label: item.label);
                              } else if (item is _ExpenseItem) {
                                final expense = item.expense;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: ExpenseCard(
                                    expense: expense,
                                    onTap: () => Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) => ExpenseDetailScreen(
                                              expense: expense,
                                            ),
                                          ),
                                        )
                                        .then((res) {
                                          if (res == true) {
                                            _fetchExpenses(forceRefresh: true);
                                          }
                                        }),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}

// ─── Filter Sheet ─────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? selectedCategory;
  final String sortBy;
  final void Function(String? category, String sort) onApply;

  const _FilterSheet({
    required this.selectedCategory,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _category;
  late String _sort;

  static const _sorts = [
    ('newest', 'Newest first'),
    ('oldest', 'Oldest first'),
    ('highest', 'Highest amount'),
    ('lowest', 'Lowest amount'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _sort = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Ledger',
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_category != null || _sort != 'newest')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _category = null;
                      _sort = 'newest';
                    });
                  },
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Sort by',
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sorts.map((s) {
              final isSel = _sort == s.$1;
              return ChoiceChip(
                label: Text(s.$2),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _sort = s.$1);
                },
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSel ? Colors.white : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  side: BorderSide(
                    color: isSel ? AppColors.ink : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text(
            'Category',
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All categories'),
                selected: _category == null,
                onSelected: (val) {
                  if (val) setState(() => _category = null);
                },
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _category == null
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  side: BorderSide(
                    color: _category == null ? AppColors.ink : AppColors.border,
                  ),
                ),
              ),
              ...[
                'Food & Dining',
                'Travel',
                'Shopping',
                'Bills',
                'Health',
                'Entertainment',
                'Education',
                'Other',
              ].map((c) {
                final isSel = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() => _category = val ? c : null);
                  },
                  selectedColor: AppColors.ink,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSel ? Colors.white : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    side: BorderSide(
                      color: isSel ? AppColors.ink : AppColors.border,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: AppTokens.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_category, _sort);
                Navigator.pop(context);
              },
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    );
  }
}
