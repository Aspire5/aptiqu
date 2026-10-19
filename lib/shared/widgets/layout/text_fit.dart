import 'package:flutter/material.dart';

/// Measure content at the learner's actual text scale before choosing columns.
bool textFits(
  BuildContext context,
  String text,
  TextStyle style,
  double width, {
  int maxLines = 1,
}) {
  if (width <= 0) return false;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
  )..layout(maxWidth: width);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  return fits;
}
