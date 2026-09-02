import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({super.key});

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

enum _BankState { initial, uploaded, processed, review }

class _BankStatementScreenState extends State<BankStatementScreen> {
  _BankState _state = _BankState.initial;
  String? _fileName;
  bool _isPdf = true;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _transactions = [
    {'merchant': 'Swiggy', 'amount': 450, 'date': '28 Aug 2026', 'category': 'Food & Dining', 'verified': true},
    {'merchant': 'Amazon Pay', 'amount': 1299, 'date': '27 Aug 2026', 'category': 'Shopping', 'verified': true},
    {'merchant': 'Netflix', 'amount': 649, 'date': '26 Aug 2026', 'category': 'Entertainment', 'verified': true},
    {'merchant': 'Unknown Merchant XZ2', 'amount': 850, 'date': '25 Aug 2026', 'category': '❓ Unrecognised', 'verified': false},
    {'merchant': 'Ola Cab', 'amount': 280, 'date': '24 Aug 2026', 'category': 'Travel', 'verified': true},
  ];

  Future<void> _pickFile(bool isPdf) async {
    setState(() => _isPdf = isPdf);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _fileName = isPdf ? 'statement_sep_2026.pdf' : 'transactions_sep_2026.csv';
      _state = _BankState.uploaded;
    });
  }

  Future<void> _process() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isProcessing = false;
      _state = _BankState.processed;
    });
  }

  Future<void> _importAll() async {
    await Future.delayed(const Duration(milliseconds: 500));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓  42 transactions imported successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop();
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
          duration: const Duration(milliseconds: 400),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _BankState.initial:
      case _BankState.uploaded:
        return _buildUploadSection();
      case _BankState.processed:
      case _BankState.review:
        return _buildReviewSection();
    }
  }

  Widget _buildUploadSection() {
    return Column(
      key: const ValueKey('upload'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Illustration
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('📄', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                'Import Bank Statement',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Upload PDF or CSV — we\'ll automatically categorize all your transactions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text('Choose File Format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _FormatButton(
                emoji: '📋',
                label: 'PDF Statement',
                isSelected: _isPdf,
                onTap: () => _pickFile(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatButton(
                emoji: '📊',
                label: 'CSV File',
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
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fileName!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Text(
                        'File selected — ready to process',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _fileName = null;
                    _state = _BankState.initial;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _isProcessing ? 'Processing...' : '🔍  Upload & Process',
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _process,
          ),
        ],

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_outlined, color: AppColors.info, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your bank statement is processed securely. We do not store your raw statement file.',
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
    final unverified = _transactions.where((t) => !t['verified']).length;

    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('📄', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '42 transactions found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '38 recognised • $unverified need review',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('Preview (5 of 42)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),

        ..._transactions.map((t) {
          final isVerified = t['verified'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isVerified ? AppColors.border : AppColors.warning,
                width: isVerified ? 1 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.check_rounded : Icons.help_outline_rounded,
                    color: isVerified ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['merchant'],
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${t['date']}  •  ${t['category']}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${t['amount']}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),

        if (unverified > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$unverified transaction(s) need your review. Tap "Import All" to categorize them manually after import.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        PrimaryButton(
          label: '✓  Import All 42 Transactions',
          onPressed: _importAll,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _state = _BankState.initial),
            child: const Text('← Upload Different File'),
          ),
        ),
      ],
    );
  }
}

class _FormatButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatButton({
    required this.emoji,
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
          color: isSelected
              ? AppColors.accent.withOpacity(0.1)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
