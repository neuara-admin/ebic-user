import 'package:flutter/material.dart';

/// Content that fills at least the available height (so `Spacer` and
/// `MainAxisAlignment.center` still work) but scrolls when it doesn't fit —
/// small phones, large system text, or the keyboard open.
class FillScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const FillScrollView({super.key, required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity),
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
