import 'package:flutter/material.dart';

import 'ui_colors.dart';

/// Bold section heading with an optional note and trailing action.
class AppSectionTitle extends StatelessWidget {
  final String text;
  final String? note;
  final Widget? trailing;
  final double fontSize;

  const AppSectionTitle(
    this.text, {
    super.key,
    this.note,
    this.trailing,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: context.uiInk,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 6),
            Text(
              '($note)',
              style: TextStyle(fontSize: 12, color: context.uiMuted),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      );
}
