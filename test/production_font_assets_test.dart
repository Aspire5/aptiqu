import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'both approved families and every used weight load from bundled assets offline',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      // Deliberately use the production asset manifest and binary messenger.
      // The presentation-font fixture override is not installed in this isolate.
      final styles = [
        for (final weight in [
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
          FontWeight.w700,
          FontWeight.w800,
        ]) ...[
          GoogleFonts.outfit(fontWeight: weight),
          GoogleFonts.plusJakartaSans(fontWeight: weight),
        ],
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                for (final style in styles)
                  Text('AptiQu 3 × 4 = 12', style: style),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('AptiQu 3 × 4 = 12'), findsNWidgets(10));
    },
  );
}
