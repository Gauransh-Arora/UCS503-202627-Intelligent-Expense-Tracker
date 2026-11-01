import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_tokens.dart';

/// Reusable App Logo widget displaying the brand asset with rounded corners
/// and optional border/shadow/hero animation support.
class AppLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final String? heroTag;

  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTokens.radiusSmall;

    Widget logoImage = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          AppConstants.assetLogo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: size,
            height: size,
            color: const Color(0xFF0F3D2E),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: logoImage);
    }

    return logoImage;
  }
}
