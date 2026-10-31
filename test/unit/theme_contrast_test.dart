import 'package:ebic_user/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG 2.2 SC 1.4.3 — normal text needs 4.5:1.
  test('white label on primary buttons meets 4.5:1', () {
    expect(_contrast(Colors.white, AppColors.primary), greaterThanOrEqualTo(4.5));
  });
  test('primary and danger text meet 4.5:1 on white and background', () {
    for (final fg in [AppColors.primary, AppColors.danger, AppColors.textPrimary, AppColors.textSecondary]) {
      expect(_contrast(fg, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(fg, AppColors.background), greaterThanOrEqualTo(4.5));
    }
  });
  test('dark theme: black label on primaryLight meets 4.5:1', () {
    expect(_contrast(Colors.black, AppColors.primaryLight), greaterThanOrEqualTo(4.5));
  });
}
