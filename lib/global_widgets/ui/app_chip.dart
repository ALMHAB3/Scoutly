import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'ui_colors.dart';

/// Selectable chip (filters, types). [soft] uses a light tint when selected
/// instead of a filled background (secondary rows such as sorting).
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool soft;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.soft = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg =
        selected ? (soft ? AppColors.primary : AppColors.white) : context.uiInk;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: soft ? 12 : 16,
            vertical: soft ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (soft
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.primary)
                : context.uiSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : context.uiBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: soft ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrolling row of chips with even spacing.
class AppChipRow extends StatelessWidget {
  final List<Widget> children;
  const AppChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final child in children)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: child,
              ),
          ],
        ),
      );
}
