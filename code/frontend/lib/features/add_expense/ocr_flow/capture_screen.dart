import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/primary_button.dart';
import 'image_preview_screen.dart';

class CaptureScreen extends StatelessWidget {
  final String type; // 'receipt' or 'upi'
  const CaptureScreen({super.key, required this.type});

  bool get isReceipt => type == 'receipt';

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            source: source == ImageSource.camera ? 'camera' : 'gallery',
            filePath: pickedFile.path,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isReceipt ? 'Scan Receipt' : 'Upload UPI Screenshot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Clean Document Target Area
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isReceipt
                          ? Icons.receipt_long_outlined
                          : Icons.phone_android_rounded,
                      size: 32,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isReceipt
                          ? 'Receipt or Invoice'
                          : 'UPI Payment Confirmation',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isReceipt
                          ? 'Position document inside frame with clear lighting'
                          : 'Select screenshot showing amount, date, and receiver',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            if (isReceipt) ...[
              PrimaryButton(
                label: 'Capture with camera',
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => _pickImage(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
            ],

            SecondaryButton(
              label: 'Select from gallery',
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              onPressed: () => _pickImage(context, ImageSource.gallery),
            ),

            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isReceipt
                          ? 'Merchant name, total, date, and line items will be extracted for your review.'
                          : 'Amount, UPI ID, and transaction timestamp will be extracted for your review.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
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
