import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import 'image_preview_screen.dart';

class CaptureScreen extends StatelessWidget {
  final String type; // 'receipt' or 'upi'
  const CaptureScreen({super.key, required this.type});

  bool get isReceipt => type == 'receipt';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isReceipt ? 'Scan Bill / Receipt' : 'Upload UPI Screenshot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Illustration
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isReceipt ? '📷' : '🖼',
                      style: const TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isReceipt
                          ? 'Point your camera at a bill or receipt'
                          : 'Select a UPI payment screenshot',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            Text(
              'Choose Source',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'How would you like to provide the image?',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            if (isReceipt) ...[
              PrimaryButton(
                label: '📷  Open Camera',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ImagePreviewScreen(source: 'camera'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            PrimaryButton(
              label: '🖼  Choose from Gallery',
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      const ImagePreviewScreen(source: 'gallery'),
                ),
              ),
            ),

            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isReceipt
                          ? 'Our AI will extract the merchant, items, amounts, and date automatically.'
                          : 'We\'ll extract the transaction amount, UPI ID, and date from the screenshot.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
