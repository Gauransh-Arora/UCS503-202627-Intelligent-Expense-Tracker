import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/num_parser.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/split_with_friends_selector.dart';


class ManualExpenseScreen extends StatefulWidget {
  final ExpenseModel? editExpense;

  /// Pre-fill fields from a shared UPI / payment text message.
  final String? prefillAmount;
  final String? prefillMerchant;
  final String? prefillNote;
  final String? prefillRawText;

  const ManualExpenseScreen({
    super.key,
    this.editExpense,
    this.prefillAmount,
    this.prefillMerchant,
    this.prefillNote,
    this.prefillRawText,
  });

  @override
  State<ManualExpenseScreen> createState() => _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends State<ManualExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food & Dining';
  String _selectedPaymentMethod = 'UPI';
  bool _isSaving = false;
  List<CategoryModel> _backendCategories = [];
  List<String> _categoryOptions = List<String>.from(AppConstants.categories);

  final List<Map<String, dynamic>> _items = [];
  SplitSelectionData? _splitData;


  @override
  void initState() {
    super.initState();
    _loadCategories();
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.editExpense != null) {
      final e = widget.editExpense!;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _merchantCtrl.text = e.merchant;
      _notesCtrl.text = e.notes ?? '';
      _selectedDate = e.date;
      _selectedCategory = e.category;
      _selectedPaymentMethod = e.paymentMethod;
      _items.addAll(
        e.items.map(
          (i) => {'name': i.name, 'quantity': i.quantity, 'price': i.price},
        ),
      );
    } else {
      // Pre-fill from shared UPI text
      if (widget.prefillAmount != null) {
        _amountCtrl.text = widget.prefillAmount!;
      }
      if (widget.prefillMerchant != null) {
        _merchantCtrl.text = widget.prefillMerchant!;
      }
      if (widget.prefillNote != null) {
        _notesCtrl.text = widget.prefillNote!;
      }
      if (widget.prefillRawText != null) {
        _selectedPaymentMethod = 'UPI';
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.ink),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Add Line Item',
          style: TextStyle(fontFamily: AppTheme.fontSans, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  _items.add({
                    'name': nameCtrl.text.trim(),
                    'quantity': 1,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _loadCategories() {
    ApiService.getCategories()
        .then((cats) {
          if (cats.isNotEmpty && mounted) {
            setState(() {
              _backendCategories = cats;
              final names = cats
                  .map((c) => c.name.trim())
                  .where((n) => n.isNotEmpty)
                  .toSet()
                  .toList();
              if (names.isNotEmpty) {
                _categoryOptions = names;
              }
              if (!_categoryOptions.contains(_selectedCategory)) {
                final selLower = _selectedCategory.toLowerCase();
                final match = _categoryOptions.where((c) {
                  final cLower = c.toLowerCase();
                  return cLower == selLower ||
                      cLower.contains(selLower) ||
                      selLower.contains(cLower);
                }).firstOrNull;
                if (match != null) {
                  _selectedCategory = match;
                } else if (_categoryOptions.isNotEmpty) {
                  _selectedCategory = _categoryOptions.first;
                }
              }
            });
          }
        })
        .catchError((_) {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final rawMethod = _selectedPaymentMethod.toLowerCase();
      final paymentMethod = rawMethod.contains('credit')
          ? 'credit_card'
          : (rawMethod.contains('debit')
                ? 'debit_card'
                : (rawMethod.contains('cash')
                      ? 'cash'
                      : (rawMethod.contains('net') || rawMethod.contains('bank')
                            ? 'net_banking'
                            : 'upi')));

      final itemsPayload = _items
          .map(
            (i) => {
              'name': i['name'],
              'quantity': asInt(i['quantity'], 1),
              'unit_price': asDouble(i['price']),
              'total_price': asDouble(i['price']) * asInt(i['quantity'], 1),
            },
          )
          .toList();

      CategoryModel? matchedCat;
      for (final c in _backendCategories) {
        if (c.name.toLowerCase() == _selectedCategory.toLowerCase()) {
          matchedCat = c;
          break;
        }
      }

      if (widget.editExpense != null) {
        final payload = <String, dynamic>{
          'merchant_name': _merchantCtrl.text.trim(),
          'amount': amount,
          'currency': 'INR',
          'transaction_date': dateStr,
          'payment_method': paymentMethod,
          'category_name': _selectedCategory,
          if (matchedCat != null) 'category_id': matchedCat.id,
          'description': _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
        };
        await ApiService.updateTransaction(widget.editExpense!.id, payload);
      } else {
        final payload = <String, dynamic>{
          'merchant_name': _merchantCtrl.text.trim(),
          'amount': amount,
          'currency': 'INR',
          'transaction_date': dateStr,
          'payment_method': paymentMethod,
          'category_name': _selectedCategory,
          if (matchedCat != null) 'category_id': matchedCat.id,
          'description': _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          'items': itemsPayload,
        };
        await ApiService.createTransaction(payload);
        if (_splitData != null && _splitData!.isEnabled && _splitData!.selectedFriends.isNotEmpty) {
          try {
            await SplitWithFriendsSelector.createSplitIfEnabled(
              isEnabled: _splitData!.isEnabled,
              splitType: _splitData!.splitType,
              selectedFriends: _splitData!.selectedFriends,
              participantShares: _splitData!.participantShares,
              title: _merchantCtrl.text.trim().isNotEmpty
                  ? _merchantCtrl.text.trim()
                  : 'Expense Split',
              totalAmount: amount,
              description: _notesCtrl.text.trim().isNotEmpty
                  ? _notesCtrl.text.trim()
                  : null,
            );
          } catch (splitErr) {
            debugPrint('[ManualExpenseScreen] Split error: $splitErr');
          }
        }

      }

      if (!mounted) return;
      final isSplitDone = _splitData != null && _splitData!.isEnabled && _splitData!.selectedFriends.isNotEmpty;
      final splitFriendsCount = _splitData?.selectedFriends.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editExpense != null
                ? 'Expense updated'
                : (isSplitDone
                    ? 'Expense recorded & split with $splitFriendsCount friend${splitFriendsCount > 1 ? "s" : ""}'
                    : 'Expense recorded'),
          ),
          backgroundColor: AppColors.credit,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        AppRouter.router.go(AppConstants.routeHome);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.debit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editExpense != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              AppRouter.router.go(AppConstants.routeHome);
            }
          },
        ),
        title: Text(isEdit ? 'Edit Expense' : 'Add Expense Manually'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // ── UPI raw-text banner ────────────────────────────────────────
            if (widget.prefillRawText != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.accent,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Parsed from shared text',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.prefillRawText!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Amount
            _FormCard(
              title: 'Amount *',
              child: TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Amount is required' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Merchant
            _FormCard(
              title: 'Merchant / Payee',
              child: TextFormField(
                controller: _merchantCtrl,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g., Swiggy, Metro, Bookstore',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Merchant is required' : null,
              ),
            ),
            const SizedBox(height: 12),

            // Date
            _FormCard(
              title: 'Date',
              child: InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category
            _FormCard(
              title: 'Category',
              child: Builder(
                builder: (context) {
                  final uniqueCategories = _categoryOptions
                      .map((c) => c.trim())
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .toList();
                  if (uniqueCategories.isEmpty) {
                    uniqueCategories.addAll(AppConstants.categories);
                  }
                  if (!uniqueCategories.contains(_selectedCategory)) {
                    final selLower = _selectedCategory.toLowerCase();
                    final match = uniqueCategories.where((c) {
                      final cLower = c.toLowerCase();
                      return cLower == selLower ||
                          cLower.contains(selLower) ||
                          selLower.contains(cLower);
                    }).firstOrNull;
                    _selectedCategory = match ?? uniqueCategories.first;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedCategory = v);
                      }
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    items: uniqueCategories
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  AppColors.categoryIcon(cat),
                                  size: 15,
                                  color: AppColors.categoryColor(cat),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontSans,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Payment method
            _FormCard(
              title: 'Payment Method',
              child: Builder(
                builder: (context) {
                  final methods = AppConstants.paymentMethods
                      .map((m) => m.trim())
                      .where((m) => m.isNotEmpty)
                      .toSet()
                      .toList();
                  final currentMethod = methods.contains(_selectedPaymentMethod)
                      ? _selectedPaymentMethod
                      : (methods.isNotEmpty ? methods.first : 'UPI');

                  return DropdownButtonFormField<String>(
                    value: currentMethod,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedPaymentMethod = v);
                      }
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    items: methods
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Line items section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Line Items (Optional)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add item',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No individual line items added.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['name'],
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '₹${asDouble(item['price']).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _items.removeAt(idx)),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!isEdit) ...[
              SplitWithFriendsSelector(
                totalAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
                onChanged: (data) => _splitData = data,
              ),
              const SizedBox(height: 12),
            ],

            // Notes
            _FormCard(
              title: 'Notes',
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Optional remark...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: isEdit ? 'Update Expense' : 'Record Expense',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _FormCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
