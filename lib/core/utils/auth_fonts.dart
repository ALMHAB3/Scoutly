import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' as google_fonts;

import '../../global_widgets/locale_controller.dart';

bool get _arabic => LocaleController.instance.locale.languageCode == 'ar';

TextStyle poppins({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? decorationColor,
  List<Shadow>? shadows,
}) {
  final style = TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
    decorationColor: decorationColor,
    shadows: shadows,
  );
  return _arabic
      ? google_fonts.GoogleFonts.cairo(textStyle: style)
      : google_fonts.GoogleFonts.poppins(textStyle: style);
}

TextStyle plusJakartaSans({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? decorationColor,
  List<Shadow>? shadows,
}) {
  final style = TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
    decorationColor: decorationColor,
    shadows: shadows,
  );
  return _arabic
      ? google_fonts.GoogleFonts.cairo(textStyle: style)
      : google_fonts.GoogleFonts.plusJakartaSans(textStyle: style);
}
