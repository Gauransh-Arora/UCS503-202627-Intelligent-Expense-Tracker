import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../../../models/expense_model.dart';

class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({super.key});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  // Pre-filled with mock OCR result
  final _merchantCtrl = TextEditingController(text: 'Restaurant ABC');
  final _amountCtrl = TextEditingController(text: '1250');
  String _selectedDate = '02 Sep 2026';
  String _selectedCategory = 'Food & Dining';
  bool _isConfirming = false;
  double _confidence = 0.92; // 92% confidence

  // Mock extracted items
  final List<Map<String, dynamic>> _items = [
    {'name': 'Paneer Butter Masala', 'price': 380.0},
    {'name': 'Dal Makhani', 'price': 320.0},
    {'name': 'Naan (4 pcs)', 'price': 200.0},
    {'name': 'Lassi ×2', 'price': 200.0},
    {'name': 'GST & Service', 'price': 150.0},
  ];

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓  Expense confirmed and saved!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isHighConfidence = _confidence >= 0.85;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Extracted Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // Confidence banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHighConfidence
                  ? AppColors.successLight
                  : AppColors.warningLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHighConfidence
                    ? AppColors.success.withOpacity(0.4)
                    : AppColors.warning.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHighConfidence
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: isHighConfidence ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHighConfidence
                            ? '✓ High Confidence (${(_confidence * 100).toStringAsFixed(0)}%)'
                            : '⚠ Some fields may be incorrect',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isHighConfidence
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHighConfidence
                            ? 'Please verify the details below and confirm.'
                            : 'Please review highlighted fields carefully.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isHighConfidence
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Merchant
          _ReviewField(
            label: 'Merchant',
            child: TextFormField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(hintText: 'Merchant name'),
            ),
          ),
          const SizedBox(height: 14),

          // Amount
          _ReviewField(
            label: 'Total Amount',
            child: TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Date + Category row
          Row(
            children: [
              Expanded(
                child: _ReviewField(
                  label: 'Date',
                  child: Text(
                    _selectedDate,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReviewField(
                  label: 'Category',
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: AppConstants.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Extracted items
          Text('Extracted Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ..._items.asMap().entries.map((entry) {
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined,
                            size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item['name'],
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        Text(
                          '₹${(item['price'] as double).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '₹${_items.fold<double>(0, (s, i) => s + (i['price'] as double)).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            label: '✓  Confirm Expense',
            isLoading: _isConfirming,
            onPressed: _confirm,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('← Retake Image'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewField extends StatelessWidget {
  final String label;
  final Widget child;
  const _ReviewField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
