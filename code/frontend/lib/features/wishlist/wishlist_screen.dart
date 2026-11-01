
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/wishlist_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';
import 'purchase_readiness_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = true;
  List<WishlistItemModel> _items = [];
  DiscretionaryBudgetModel? _budgetInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getWishlistItems(forceRefresh: forceRefresh),
        ApiService.calculateDiscretionaryBudget(forceRefresh: forceRefresh)
            .then<DiscretionaryBudgetModel?>((b) => b)
            .catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        _items = results[0] as List<WishlistItemModel>;
        _budgetInfo = results[1] as DiscretionaryBudgetModel?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _addWishlistItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add to Wishlist',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'e.g. Sony WH-1000XM5',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Expected Price (₹)',
                      hintText: 'e.g. 24990',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. For work and study',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Priority',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['low', 'medium', 'high'].map((p) {
                      final isSel = priority == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => priority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: isSaving ? 'Saving...' : 'Add Item',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final price =
                                double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                            if (name.isEmpty || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid item name and price',
                                  ),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);
                            try {
                              await ApiService.addWishlistItem(
                                name: name,
                                expectedPrice: price,
                                priority: priority,
                                description: descCtrl.text.trim().isNotEmpty
                                    ? descCtrl.text.trim()
                                    : null,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item added to wishlist'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add item: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await ApiService.deleteWishlistItem(itemId);
      setState(() {
        _items.removeWhere((item) => item.id == itemId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item removed from wishlist'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete item: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wishlist & Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: _addWishlistItem,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Discretionary budget summary card
                  if (_budgetInfo != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Discretionary Budget',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormatter.format(
                              _budgetInfo!.monthlyDiscretionary,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildBudgetStat(
                                'Avg Monthly Spend',
                                currencyFormatter.format(
                                  _budgetInfo!.avgMonthlySpending,
                                ),
                              ),
                              _buildBudgetStat(
                                'Recurring Bills',
                                currencyFormatter.format(
                                  _budgetInfo!.monthlyRecurring,
                                ),
                              ),
                              _buildBudgetStat(
                                'Savings Reserve',
                                currencyFormatter.format(
                                  _budgetInfo!.savingsReserve,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Purchase readiness evaluates planned items against your monthly spending, recurring bills, and savings.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Planned Items (${_items.length})',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: _addWishlistItem,
                        child: const Text(
                          'Add Item',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_items.isEmpty)
                    _buildEmptyState()
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _WishlistCard(
                          item: item,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PurchaseReadinessScreen(item: item),
                                  ),
                                )
                                .then((_) => _loadData());
                          },
                          onDelete: () => _deleteItem(item.id),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildBudgetStat(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Wishlist is Empty',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add items you plan to buy to evaluate purchase readiness.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _addWishlistItem,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              ),
            ),
            child: const Text(
              'Add Item',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final WishlistItemModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WishlistCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  Color get _readinessColor {
    switch (item.readiness) {
      case AppConstants.readinessComfortable:
        return AppColors.success;
      case AppConstants.readinessPossible:
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _readinessColor;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
          size: 20,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Icon(item.readinessIcon, size: 16, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSmall,
                            ),
                          ),
                          child: Text(
                            item.readiness,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (item.priority.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${item.priority[0].toUpperCase()}${item.priority.substring(1)} priority',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Readiness',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
