import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'ocr_review_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;

  final List<_ExtractionStep> _steps = [
    _ExtractionStep(label: 'Merchant Name', icon: '🏪'),
    _ExtractionStep(label: 'Total Amount', icon: '💰'),
    _ExtractionStep(label: 'Date & Time', icon: '📅'),
    _ExtractionStep(label: 'Line Items', icon: '📋'),
    _ExtractionStep(label: 'Category', icon: '🏷️'),
  ];

  int _completedSteps = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();

    // Simulate step-by-step extraction
    for (int i = 0; i < _steps.length; i++) {
      Future.delayed(Duration(milliseconds: 600 + i * 700), () {
        if (mounted) setState(() => _completedSteps = i + 1);
      });
    }

    // Navigate to review after processing
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OcrReviewScreen()),
      );
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent
                        .withOpacity(0.1 + _pulseCtrl.value * 0.1),
                    border: Border.all(
                      color: AppColors.accent
                          .withOpacity(0.4 + _pulseCtrl.value * 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Analyzing your receipt...',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Our AI is extracting the details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Progress bar
              AnimatedBuilder(
                animation: _progressCtrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressCtrl.value,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Extraction steps
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracting:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._steps.asMap().entries.map((entry) {
                      final i = entry.key;
                      final step = entry.value;
                      final isDone = i < _completedSteps;
                      final isActive = i == _completedSteps;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? AppColors.success
                                    : isActive
                                        ? AppColors.accent.withOpacity(0.2)
                                        : AppColors.border,
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 14)
                                    : isActive
                                        ? SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.accent,
                                            ),
                                          )
                                        : const Icon(Icons.circle_outlined,
                                            size: 14,
                                            color: AppColors.textTertiary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(step.icon),
                            const SizedBox(width: 8),
                            Text(
                              step.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isDone
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isDone
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtractionStep {
  final String label;
  final String icon;
  const _ExtractionStep({required this.label, required this.icon});
}
