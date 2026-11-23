import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'ui_colors.dart';

/// Square tile with an icon and a label (features, amenities). With
/// [onTap] it works as a toggle.
class AppFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int maxLines;

  const AppFeatureTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.uiInk;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.10)
            : context.uiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : context.uiBorder,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: tile,
      ),
    );
  }
}
