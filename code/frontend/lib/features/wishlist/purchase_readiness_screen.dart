
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/wishlist_model.dart';
import '../../services/api_service.dart';

class PurchaseReadinessScreen extends StatefulWidget {
  final WishlistItemModel item;

  const PurchaseReadinessScreen({super.key, required this.item});

  @override
  State<PurchaseReadinessScreen> createState() =>
      _PurchaseReadinessScreenState();
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

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final verdict = _readinessData?.verdict ?? widget.item.readiness;
    final verdictColor = _getVerdictColor(verdict);
    final readinessScore =
        _readinessData?.purchaseReadiness ??
        widget.item.purchaseReadiness ??
        65.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Purchase Readiness')),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // ─── Top Typographic Assessment Card ─────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.item.formattedPrice,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: verdictColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                            ),
                            child: Text(
                              verdict,
                              style: TextStyle(
                                color: verdictColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 14),

                      // Affordability Score (restrained thin indicator)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Affordability Score',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${readinessScore.clamp(0, 100).toStringAsFixed(0)} / 100',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (readinessScore / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            verdictColor,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Financial Breakdown Context ────────────────────────────
                Text(
                  'Financial Evaluation',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _FinancialRow(
                        label: 'Monthly Discretionary Budget',
                        value: _readinessData != null
                            ? currencyFormatter.format(
                                _readinessData!.monthlyDiscretionary,
                              )
                            : 'Pending',
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        color: AppColors.border,
                      ),
                      _FinancialRow(
                        label: 'Average Monthly Spending',
                        value: _readinessData != null
                            ? currencyFormatter.format(
                                _readinessData!.avgMonthlySpending,
                              )
                            : 'Pending',
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        color: AppColors.border,
                      ),
                      _FinancialRow(
                        label: 'Estimated Saving Timeline',
                        value: _readinessData?.estimatedMonths != null
                            ? '${_readinessData!.estimatedMonths!.toStringAsFixed(1)} months'
                            : (verdict.toLowerCase().contains('comfortable')
                                  ? 'Immediately Affordable'
                                  : '1 - 2 months'),
                        highlightColor: verdictColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Analysis Notes ──────────────────────
                if (_readinessData?.analysisNotes.isNotEmpty ?? false) ...[
                  Text(
                    'Analysis Notes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: _readinessData!.analysisNotes
                          .asMap()
                          .entries
                          .map((entry) {
                            final i = entry.key;
                            final note = entry.value;
                            final isLast =
                                i == _readinessData!.analysisNotes.length - 1;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.arrow_right_rounded,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    color: AppColors.border,
                                  ),
                              ],
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlightColor;

  const _FinancialRow({
    required this.label,
    required this.value,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
