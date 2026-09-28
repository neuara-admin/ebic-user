@Tags(['audit'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audit_fonts.dart';

const _fontsDir = String.fromEnvironment('AUDIT_FONTS');

// With the test font every glyph is 1em wide, so 'iiii' == 'MMMM'. With real
// fonts loaded, 'iiii' is much narrower.
void main() {
  setUpAll(() => loadAuditFonts(_fontsDir));

  test('real font metrics are in use', () {
    double width(String s, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style.copyWith(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    for (final style in [
      GoogleFonts.inter(fontWeight: FontWeight.w800),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      const TextStyle(fontFamily: 'Roboto'),
    ]) {
      final narrow = width('iiii', style);
      final wide = width('MMMM', style);
      // ignore: avoid_print
      print('${style.fontFamily}: iiii=$narrow MMMM=$wide');
      expect(narrow, lessThan(wide * 0.6));
    }
  });
}
