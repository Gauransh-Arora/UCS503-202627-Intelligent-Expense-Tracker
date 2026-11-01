import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';

/// Chunky 3D tactile button system (Duolingo-inspired).
/// Features a solid surface with a distinct bottom bevel depth and tactile feedback.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final bg = widget.backgroundColor ?? AppColors.primary;
    final fg = widget.textColor ?? Colors.white;
    final depthColor = isDisabled ? Colors.transparent : AppColors.buttonDepth;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: AppTokens.buttonHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
          top: _isPressed && !isDisabled ? 2.0 : 0.0,
          bottom: _isPressed && !isDisabled ? 1.0 : 3.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: depthColor,
              offset: Offset(0, _isPressed && !isDisabled ? 1.0 : 3.0),
              blurRadius: 0,
            ),
          ],
        ),
        child: Listener(
          onPointerDown: (_) {
            if (!isDisabled) setState(() => _isPressed = true);
          },
          onPointerUp: (_) {
            if (!isDisabled) setState(() => _isPressed = false);
          },
          onPointerCancel: (_) {
            if (!isDisabled) setState(() => _isPressed = false);
          },
          child: ElevatedButton(
            onPressed: isDisabled ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: AppColors.surfaceElevated,
              disabledForegroundColor: AppColors.textTertiary,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                side: isDisabled
                    ? const BorderSide(color: AppColors.border, width: 1.5)
                    : BorderSide.none,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: isDisabled ? AppColors.textTertiary : fg,
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

/// Outlined chunky tactile secondary button
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: AppTokens.buttonHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
          top: _isPressed && !isDisabled ? 2.0 : 0.0,
          bottom: _isPressed && !isDisabled ? 1.0 : 3.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: isDisabled
                  ? Colors.transparent
                  : AppColors.buttonDepthLight,
              offset: Offset(0, _isPressed && !isDisabled ? 1.0 : 3.0),
              blurRadius: 0,
            ),
          ],
        ),
        child: Listener(
          onPointerDown: (_) {
            if (!isDisabled) setState(() => _isPressed = true);
          },
          onPointerUp: (_) {
            if (!isDisabled) setState(() => _isPressed = false);
          },
          onPointerCancel: (_) {
            if (!isDisabled) setState(() => _isPressed = false);
          },
          child: OutlinedButton(
            onPressed: isDisabled ? null : widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              disabledForegroundColor: AppColors.textTertiary,
              backgroundColor: AppColors.surfaceCard,
              side: BorderSide(
                color: isDisabled ? AppColors.border : AppColors.borderStrong,
                width: 2,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textSecondary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
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

/// TactileButton alias for backward compatibility
class TactileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final Color backgroundColor;
  final Color bottomDepthColor;
  final Color textColor;
  final double? width;
  final bool isOutlined;
  final Color outlineColor;

  const TactileButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    required this.backgroundColor,
    required this.bottomDepthColor,
    required this.textColor,
    this.width,
    this.isOutlined = false,
    this.outlineColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SecondaryButton(
        label: label,
        onPressed: onPressed,
        isLoading: isLoading,
        icon: icon,
        width: width,
      );
    }
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      width: width,
    );
  }
}
