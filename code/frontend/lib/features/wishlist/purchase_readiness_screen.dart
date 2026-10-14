import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/wishlist_model.dart';
import '../../services/api_service.dart';

class PurchaseReadinessScreen extends StatefulWidget {
  final WishlistItemModel item;

  const PurchaseReadinessScreen({super.key, required this.item});

  @override
  State<PurchaseReadinessScreen> createState() => _PurchaseReadinessScreenState();
}

class _PurchaseReadinessScreenState extends State<PurchaseReadinessScreen> {
  bool _isLoading = true;
  ReadinessResponseModel? _readinessData;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
  }

  Future<void> _loadReadiness() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.calculatePurchaseReadiness(widget.item.id);
      if (!mounted) return;
      setState(() {
        _readinessData = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Color _getVerdictColor(String verdict) {
    final v = verdict.toLowerCase();
    if (v.contains('comfortable')) return AppColors.success;
    if (v.contains('possible')) return AppColors.warning;
    return AppColors.danger;
  }

  IconData _getVerdictIcon(String verdict) {
    final v = verdict.toLowerCase();
    if (v.contains('comfortable')) return Icons.check_circle_rounded;
    if (v.contains('possible')) return Icons.info_rounded;
    return Icons.warning_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final verdict = _readinessData?.verdict ?? widget.item.readiness;
    final verdictColor = _getVerdictColor(verdict);
    final verdictIcon = _getVerdictIcon(verdict);
    final readinessScore = _readinessData?.purchaseReadiness ?? widget.item.purchaseReadiness ?? 65.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Readiness'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ─── Top Item Overview Card ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: verdictColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            verdictIcon,
                            size: 36,
                            color: verdictColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.item.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.formattedPrice,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Clean Badge - NO EMOJIS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: verdictColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: verdictColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(verdictIcon, size: 18, color: verdictColor),
                            const SizedBox(width: 8),
                            Text(
                              verdict,
                              style: TextStyle(
                                color: verdictColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Readiness Score Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Affordability Score',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${readinessScore.clamp(0, 100).toStringAsFixed(0)} / 100',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: verdictColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (readinessScore / 100).clamp(0.0, 1.0),
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(verdictColor),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Financial Breakdown Context ────────────────────────────
                Text(
                  'Financial Evaluation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _FinancialRow(
                        label: 'Monthly Discretionary Budget',
                        value: _readinessData != null
                            ? currencyFormatter.format(_readinessData!.monthlyDiscretionary)
                            : 'Evaluated by AI',
                        color: AppColors.primary,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const Divider(height: 20),
                      _FinancialRow(
                        label: 'Average Monthly Spending',
                        value: _readinessData != null
                            ? currencyFormatter.format(_readinessData!.avgMonthlySpending)
                            : 'Tracked',
                        color: AppColors.textPrimary,
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const Divider(height: 20),
                      _FinancialRow(
                        label: 'Estimated Saving Timeline',
                        value: _readinessData?.estimatedMonths != null
                            ? '${_readinessData!.estimatedMonths!.toStringAsFixed(1)} months'
                            : (verdict.toLowerCase().contains('comfortable') ? 'Immediately Affordable' : '1 - 2 months'),
                        color: verdictColor,
                        icon: Icons.timelapse_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── AI Analysis & Recommendation Notes ──────────────────────
                if (_readinessData?.analysisNotes.isNotEmpty ?? false) ...[
                  Text(
                    'Smart Analysis Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ..._readinessData!.analysisNotes.map((note) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _FinancialRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
