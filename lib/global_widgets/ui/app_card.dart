import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'ui_colors.dart';

/// The app's card / box: surface colour, rounded corners, border and a soft
/// shadow in light mode. Pass [onTap] to make the whole card tappable.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool shadow;
  final VoidCallback? onTap;
  final Gradient? gradient;

  /// Clip children to the rounded corners (e.g. a photo at the top).
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 16,
    this.color,
    this.borderColor,
    this.shadow = true,
    this.onTap,
    this.gradient,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? context.uiSurface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? context.uiBorder),
        boxShadow: !shadow || context.uiIsDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}
