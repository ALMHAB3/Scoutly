import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'ui_colors.dart';

enum AppIconButtonStyle {
  /// White (surface) circle, e.g. over photos: back, favorite.
  surface,

  /// Light primary tint, e.g. counters' + and -.
  tinted,
}

/// Round icon button used across the app.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonStyle style;
  final Color? color;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.style = AppIconButtonStyle.surface,
    this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (style == AppIconButtonStyle.tinted) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          disabledBackgroundColor: context.uiBorder.withValues(alpha: 0.4),
        ),
        icon: Icon(
          icon,
          size: size,
          color: enabled ? (color ?? AppColors.primary) : context.uiMuted,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: context.uiSurface.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: size, color: color ?? context.uiInk),
        ),
      ),
    );
  }
}
