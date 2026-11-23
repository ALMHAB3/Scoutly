import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'ui_colors.dart';

/// Rating pill "4.8 ★" (hidden when there is no rating).
class AppRatingBadge extends StatelessWidget {
  final double rating;
  const AppRatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.uiSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: context.uiInk,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.star_rounded,
              color: AppColors.accentYellow, size: 16),
        ],
      ),
    );
  }
}

/// Small white pill with an icon, e.g. "184 m away" over a photo.
class AppPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const AppPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.uiSurface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: context.uiInk,
              ),
            ),
          ],
        ),
      );
}

/// "icon  label" line in the primary colour (e.g. "Provided by ...").
class AppIconLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final double fontSize;
  final Color? color;
  final int maxLines;

  const AppIconLabel({
    super.key,
    required this.icon,
    required this.text,
    this.fontSize = 12,
    this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        Icon(icon, size: fontSize + 3, color: c),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ),
      ],
    );
  }
}
