import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Light/dark aware colours used by the shared UI widgets.
/// Usage: `context.uiInk`, `context.uiSurface`...
extension UiColors on BuildContext {
  bool get uiIsDark => Theme.of(this).brightness == Brightness.dark;

  /// Page background behind cards.
  Color get uiPageBackground =>
      uiIsDark ? AppColors.darkBackground : AppColors.background;

  /// Card / sheet background.
  Color get uiSurface => uiIsDark ? AppColors.darkSurface : AppColors.surface;

  /// Card borders and dividers.
  Color get uiBorder => uiIsDark ? AppColors.darkBorder : AppColors.border;

  /// Main text.
  Color get uiInk =>
      uiIsDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  /// Secondary text and icons.
  Color get uiMuted =>
      uiIsDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
}
