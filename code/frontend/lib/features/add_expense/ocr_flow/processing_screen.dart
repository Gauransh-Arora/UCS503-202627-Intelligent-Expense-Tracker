import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../services/api_service.dart';
import 'ocr_review_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String filePath;
  const ProcessingScreen({super.key, required this.filePath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final List<String> _stages = const [
    'Uploading document',
    'Locating merchant & transaction date',
    'Detecting line items & total',
    'Categorizing expense',
  ];

  int _currentStage = 0;

  @override
  void initState() {
    super.initState();
    _processDocument();
  }

  Future<void> _processDocument() async {
    try {
      if (mounted) setState(() => _currentStage = 0);
      final docId = await ApiService.uploadDocument(widget.filePath);

      if (mounted) setState(() => _currentStage = 1);
      final ocrResult = await ApiService.processDocument(docId);

      if (mounted) setState(() => _currentStage = 3);

      // Attach local image path for the review screen to display side-by-side
      final Map<String, dynamic> enrichedResult = Map<String, dynamic>.from(
        ocrResult,
      );
      enrichedResult['local_image_path'] = widget.filePath;

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrReviewScreen(ocrData: enrichedResult),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Document processing failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.debit,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        AppRouter.router.go(AppConstants.routeHome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Extracting Document Details',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reading values from invoice and categorizing entries',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Processing steps checklist
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: _stages.asMap().entries.map((entry) {
                      final i = entry.key;
                      final label = entry.value;
                      final isComplete = i <= _currentStage;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              isComplete
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isComplete
                                  ? AppColors.accent
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSans,
                                  fontSize: 13,
                                  fontWeight: isComplete
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isComplete
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
