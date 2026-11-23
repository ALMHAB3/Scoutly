import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum AppButtonVariant {
  /// Main action: navy gradient (Book Now, Pay, Search...).
  primary,

  /// Secondary action: outlined in the primary colour.
  secondary,

  /// Link-style action without a background.
  text,
}

/// The app's one button. Same parameters as Flutter's buttons
/// (`onPressed`, `child` / `icon` + `label`, `style`) plus:
/// * [variant]: primary (default), secondary or text;
/// * [loading]: shows a spinner and disables the button;
/// * [expand]: full width (default for primary and secondary).
///
/// ```dart
/// AppButton(onPressed: _pay, child: Text(l10n.pay))
/// AppButton.icon(onPressed: _search, icon: Icon(Icons.search), label: Text('Search'))
/// AppButton(variant: AppButtonVariant.secondary, onPressed: _cancel, child: Text('Cancel'))
/// ```
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final AppButtonVariant variant;
  final bool loading;
  final bool? expand;
  final double? height;
  final ButtonStyle? style;

  const AppButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand,
    this.height,
    this.style,
  })  : icon = null,
        label = null;

  const AppButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand,
    this.height,
    this.style,
  }) : child = null;

  /// Plain text shortcut: `AppButton.label(text: 'Pay', onPressed: _pay)`.
  AppButton.label({
    super.key,
    required String text,
    required this.onPressed,
    IconData? iconData,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand,
    this.height,
    this.style,
  })  : child = iconData == null ? Text(text) : null,
        icon = iconData == null ? null : Icon(iconData, size: 20),
        label = iconData == null ? null : Text(text);

  static const radius = 16.0;
  static const defaultHeight = 54.0;

  bool get _enabled => onPressed != null && !loading;

  Widget _content(Color spinnerColor) {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: spinnerColor),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme.merge(data: const IconThemeData(size: 20), child: icon!),
          const SizedBox(width: 8),
          Flexible(child: label!),
        ],
      );
    }
    return child!;
  }

  @override
  Widget build(BuildContext context) {
    // A style with its own size (minimumSize / fixedSize) keeps that size.
    final customSize = style?.minimumSize != null || style?.fixedSize != null;
    final fullWidth =
        !customSize && (expand ?? variant != AppButtonVariant.text);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final h = customSize
        ? null
        : height ?? (variant == AppButtonVariant.text ? null : defaultHeight);
    final minimumSize = Size(fullWidth ? double.infinity : 0, h ?? 40);
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        final customBackground = style?.backgroundColor != null;
        final base = ElevatedButton.styleFrom(
          backgroundColor: customBackground ? null : AppColors.transparent,
          disabledBackgroundColor: AppColors.transparent,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white70,
          shadowColor: AppColors.transparent,
          elevation: 0,
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: textStyle,
        );
        final inner = ElevatedButton(
          onPressed: _enabled ? onPressed : null,
          style: style?.merge(base) ?? base,
          child: _content(AppColors.white),
        );
        button = customBackground
            ? inner
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _enabled ? AppColors.primaryGradient : null,
                  color: _enabled ? null : AppColors.textHint,
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: _enabled
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.26),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : const [],
                ),
                child: inner,
              );
      case AppButtonVariant.secondary:
        final base = OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: _enabled
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.textHint,
            width: 1.4,
          ),
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: shape,
          textStyle: textStyle,
        );
        button = OutlinedButton(
          onPressed: _enabled ? onPressed : null,
          style: style?.merge(base) ?? base,
          child: _content(AppColors.primary),
        );
      case AppButtonVariant.text:
        final base = TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: fullWidth ? Size(double.infinity, h ?? 44) : null,
          shape: shape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        );
        button = TextButton(
          onPressed: _enabled ? onPressed : null,
          style: style?.merge(base) ?? base,
          child: _content(AppColors.primary),
        );
    }
    return h == null || !fullWidth
        ? button
        : SizedBox(width: double.infinity, height: h, child: button);
  }
}
