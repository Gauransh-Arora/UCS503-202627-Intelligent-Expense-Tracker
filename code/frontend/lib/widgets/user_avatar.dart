import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// Reusable user avatar widget using DiceBear voxel-art SVG avatars.
/// Uses transparent background by default so it blends seamlessly into the card/screen background.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? emailSeed;
  final String initials;
  final double size;
  final double? borderRadius;
  final BoxBorder? border;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.emailSeed,
    this.initials = 'U',
    this.size = 44,
    this.borderRadius,
    this.border,
    this.backgroundColor,
  });

  String _resolveUrl() {
    String raw;
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      raw = avatarUrl!.trim();
    } else {
      final seed = (emailSeed != null && emailSeed!.trim().isNotEmpty)
          ? emailSeed!.trim()
          : initials;
      raw =
          'https://api.dicebear.com/10.x/voxel-art/svg?seed=${Uri.encodeComponent(seed)}';
    }
    // Default to transparent background (00000000) so it matches the parent surface
    if (!raw.contains('backgroundColor=')) {
      raw += '${raw.contains('?') ? '&' : '?'}backgroundColor=00000000';
    }
    return raw;
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? AppColors.surfaceElevated,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTokens.radiusSmall;
    final url = _resolveUrl();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => _buildFallback(),
        ),
      ),
    );
  }
}
