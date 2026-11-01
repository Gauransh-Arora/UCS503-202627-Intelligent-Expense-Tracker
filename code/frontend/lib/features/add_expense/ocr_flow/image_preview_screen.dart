import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/primary_button.dart';
import 'processing_screen.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String source;
  final String? filePath;
  const ImagePreviewScreen({super.key, required this.source, this.filePath});

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      AppRouter.router.go(AppConstants.routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _handleBack(context),
        ),
        title: const Text('Review Image'),
      ),
      body: Column(
        children: [
          // Image preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge - 1),
                child: filePath != null
                    ? Image.file(
                        File(filePath!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.textTertiary,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Document preview unavailable',
                              style: TextStyle(
                                fontFamily: AppTheme.fontSans,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Retake',
                      onPressed: () => _handleBack(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'Extract details',
                      onPressed: () {
                        if (filePath != null) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProcessingScreen(filePath: filePath!),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
