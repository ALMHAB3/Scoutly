import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'app_icon_button.dart';
import 'ui_colors.dart';

/// "Label   (-) 2 (+)" row, e.g. rooms, guests, travellers.
class AppCounter extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const AppCounter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.min = 0,
    this.max = 99,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.uiInk,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11.5, color: context.uiMuted),
                    ),
                ],
              ),
            ),
            AppIconButton(
              icon: Icons.remove_rounded,
              tooltip: '$label -',
              style: AppIconButtonStyle.tinted,
              size: 18,
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.uiInk,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.add_rounded,
              tooltip: '$label +',
              style: AppIconButtonStyle.tinted,
              size: 18,
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      );
}
