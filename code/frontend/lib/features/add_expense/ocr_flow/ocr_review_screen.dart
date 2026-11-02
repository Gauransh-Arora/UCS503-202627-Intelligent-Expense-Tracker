import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/num_parser.dart';
import '../../../widgets/primary_button.dart';
import '../../../services/api_service.dart';
import '../../../widgets/split_with_friends_selector.dart';


class OcrReviewScreen extends StatefulWidget {
  final Map<String, dynamic> ocrData;
  const OcrReviewScreen({super.key, required this.ocrData});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late String _selectedDate;
  late String _selectedCategory;
  bool _isConfirming = false;
  late double _confidence;
  String? _localImagePath;

  late final List<Map<String, dynamic>> _items;
  SplitSelectionData? _splitData;


  @override
  void initState() {
    super.initState();
    final data = widget.ocrData;
    _merchantCtrl = TextEditingController(text: data['merchant_name'] ?? '');
    _amountCtrl = TextEditingController(text: data['amount']?.toString() ?? '');

    _selectedDate =
        data['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedCategory = data['category_suggestion'] ?? 'Food & Dining';
    _confidence = asDouble(data['confidence'], 0.0);
    _localImagePath = data['local_image_path'] as String?;

    _items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });

  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);

    try {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
      String dateStr;
      try {
        final parsed = DateTime.parse(_selectedDate);
        dateStr = DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {
        dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      final itemsPayload = _items
          .map(
            (i) => {
              'name': i['name'] ?? 'Item',
              'quantity': asInt(i['quantity'], 1),
              'unit_price': asDouble(i['unit_price'] ?? i['price']),
              'total_price': asDouble(i['total_price'] ?? i['price']),
            },
          )
          .toList();

      final payload = <String, dynamic>{
        'merchant_name': _merchantCtrl.text.trim().isNotEmpty
            ? _merchantCtrl.text.trim()
            : 'Unknown Merchant',
        'amount': amount > 0 ? amount : 1.0,
        'currency': 'INR',
        'transaction_date': dateStr,
        'payment_method': 'upi',
        'category_name': _selectedCategory,
        if (widget.ocrData['document_id'] != null)
          'document_id': widget.ocrData['document_id'],
        'description': 'Verified receipt via OCR',
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
                : 'OCR Expense Split',
            totalAmount: amount > 0 ? amount : 1.0,
            description: 'Split from OCR receipt / transaction',
          );
        } catch (splitErr) {
          debugPrint('[OcrReviewScreen] Split error: $splitErr');
        }
      }


      if (!mounted) return;
      setState(() => _isConfirming = false);
      final isSplitDone = _splitData != null && _splitData!.isEnabled && _splitData!.selectedFriends.isNotEmpty;
      final splitFriendsCount = _splitData?.selectedFriends.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSplitDone
                ? 'Expense recorded & split with $splitFriendsCount friend${splitFriendsCount > 1 ? "s" : ""}'
                : 'Expense confirmed and recorded',
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
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to record expense: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.debit,
        ),
      );
    }
  }

  Future<void> _discardDraft() async {
    final docId = widget.ocrData['document_id'];
    if (docId != null) {
      try {
        await ApiService.deleteDocument(docId.toString());
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft discarded')));
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      AppRouter.router.go(AppConstants.routeHome);
    }
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: asDouble(item['total_price'] ?? item['price']).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Edit Item',
          style: TextStyle(fontFamily: AppTheme.fontSans, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
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
              final newName = nameCtrl.text.trim();
              final newPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (newName.isNotEmpty) {
                setState(() {
                  _items[index]['name'] = newName;
                  _items[index]['total_price'] = newPrice;
                  _items[index]['price'] = newPrice;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = _confidence > 0 && _confidence < 0.75;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Extracted Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              AppRouter.router.go(AppConstants.routeHome);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ─── Source Document Thumbnail / Strip ───────────────────────────
          if (_localImagePath != null &&
              File(_localImagePath!).existsSync()) ...[
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppTokens.radiusMedium - 1),
                    ),
                    child: Image.file(
                      File(_localImagePath!),
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Source Document',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cross-check values with original receipt',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSans,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Low-confidence quiet flag (not a giant rainbow banner)
          if (isLowConfidence) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confidence (${(_confidence * 100).toStringAsFixed(0)}%): please check marked values.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── Extracted Fields Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Merchant
                const Text(
                  'Merchant',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _merchantCtrl,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Merchant name',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Date & Category
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontFamily: AppTheme.fontSans,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 44,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _selectedDate,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              fontFamily: AppTheme.fontSans,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                ),
                                items: AppConstants.categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontSans,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedCategory = v!),
                                value:
                                    AppConstants.categories.contains(
                                      _selectedCategory,
                                    )
                                    ? _selectedCategory
                                    : AppConstants.categories.first,
                              ),
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
          const SizedBox(height: 16),

          // ─── Line Items (Editable Table) ──────────────────────────────────
          if (_items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXTRACTED LINE ITEMS',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return InkWell(
                      onTap: () => _editItem(idx),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['name'] ?? 'Item',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '₹${asDouble(item['total_price'] ?? item['price']).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSans,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total itemized',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${_items.fold<double>(0, (s, i) => s + asDouble(i['total_price'] ?? i['price'])).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Split with friends selector ──────────────────────────────
          SplitWithFriendsSelector(
            totalAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
            onChanged: (data) => _splitData = data,
          ),
          const SizedBox(height: 16),

          // ─── Obvious Confirm vs Discard Actions ───────────────────────────
          PrimaryButton(
            label: 'Confirm Expense',
            isLoading: _isConfirming,
            onPressed: _confirm,
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Discard Draft', onPressed: _discardDraft),
        ],
      ),
    );
  }
}
