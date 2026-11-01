import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
        title: const Text('Expenses'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: _showFilterSheet,
              ),
              if (_selectedCategory != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: AppColors.danger),
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Active filters
                if (_selectedCategory != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Chip(
                          label: Text(_selectedCategory!),
                          onDeleted: () =>
                              setState(() => _selectedCategory = null),
                          deleteIconColor: AppColors.accent,
                          backgroundColor: AppColors.accent.withOpacity(0.1),
                          labelStyle: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expense list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetchExpenses(forceRefresh: true),
                    child: listItems.isEmpty
                        ? EmptyState(
                            icon: Icons.search_rounded,
                            title: 'No expenses found',
                            description: _searchQuery.isNotEmpty
                                ? 'No results for "$_searchQuery"'
                                : 'No expenses match your current filters',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: listItems.length,
                            itemBuilder: (context, index) {
                              final item = listItems[index];
                              if (item is _DateHeaderItem) {
                                return _DateHeader(label: item.label);
                              } else if (item is _ExpenseItem) {
                                final expense = item.expense;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
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
                                          if (res == true)
                                            _fetchExpenses(forceRefresh: true);
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
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
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
  List<String> _categories = [
    'Food & Dining',
    'Travel',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Other',
  ];

  static const _sorts = [
    ('newest', 'Newest First'),
    ('oldest', 'Oldest First'),
    ('highest', 'Highest Amount'),
    ('lowest', 'Lowest Amount'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _sort = widget.sortBy;
    ApiService.getCategories()
        .then((cats) {
          if (cats.isNotEmpty && mounted) {
            setState(() => _categories = cats.map((c) => c.name).toList());
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Filter & Sort',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ..._categories.map(
                  (cat) => FilterChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(
                      () => _category = _category == cat ? null : cat,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Sort By', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._sorts.map(
              (s) => RadioListTile<String>(
                title: Text(s.$2),
                value: s.$1,
                groupValue: _sort,
                onChanged: (v) => setState(() => _sort = v!),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _category = null;
                        _sort = 'newest';
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_category, _sort);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
