import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class TactileButton extends StatefulWidget {
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
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  static const double _depth = 6.0;

  void _onTapDown(_) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(_) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    final currentBackgroundColor = isDisabled
        ? AppColors.border
        : widget.backgroundColor;
    final currentDepthColor = isDisabled
        ? AppColors.border.withOpacity(0.5)
        : widget.bottomDepthColor;
    final currentTextColor = isDisabled
        ? AppColors.textTertiary
        : widget.textColor;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: 60, // Fixed height to account for depth
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Depth layer (bottom)
            Container(
              height: 56, // Slightly shorter to create depth
              decoration: BoxDecoration(
                color: currentDepthColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Top clickable layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeInOut,
              bottom: _isPressed || isDisabled ? 0 : _depth,
              left: 0,
              right: 0,
              top: _isPressed || isDisabled ? _depth : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: currentBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: widget.isOutlined
                      ? Border.all(color: widget.outlineColor, width: 2)
                      : null,
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: currentTextColor,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              widget.icon!,
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: currentTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TactileButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: backgroundColor ?? AppColors.primary,
      bottomDepthColor: AppColors.primaryDark,
      textColor: textColor ?? Colors.white,
      width: width,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      backgroundColor: AppColors.surfaceCard,
      bottomDepthColor: AppColors.border,
      textColor: AppColors.primary,
      isOutlined: true,
      outlineColor: AppColors.border,
    );
  }
}
