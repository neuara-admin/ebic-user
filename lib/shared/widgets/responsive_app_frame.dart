import 'package:flutter/material.dart';

/// App-wide layout guards for different devices. Used as `MaterialApp.builder`
/// so it also covers dialogs, bottom sheets and snackbars.
///
/// - Caps the system font size at [maxTextScale] (Android allows up to 2x,
///   which breaks most layouts) while still honouring "large text" settings.
/// - Enforces [Brightness.light] so device system dark mode never leaks
///   unreadable dark patches or misaligned contrast into the UI.
/// - On tablets / wide windows, shows the phone-first UI in a centred column
///   no wider than [maxContentWidth] on a warm neutral gutter.
class ResponsiveAppFrame extends StatelessWidget {
  static const double maxContentWidth = 600;
  static const double maxTextScale = 1.3;

  final Widget? child;

  const ResponsiveAppFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final textScaler = mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: maxTextScale);
    final lightMq = mq.copyWith(
      textScaler: textScaler,
      platformBrightness: Brightness.light,
    );
    final content = child ?? const SizedBox.shrink();

    if (mq.size.width <= maxContentWidth) {
      return MediaQuery(data: lightMq, child: content);
    }

    // Wide screen: centre a phone-width column and tell it its real width.
    return ColoredBox(
      color: const Color(0xFFEFEFEA),
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          child: MediaQuery(
            data: lightMq.copyWith(
              size: Size(maxContentWidth, mq.size.height),
            ),
            child: ClipRect(child: content),
          ),
        ),
      ),
    );
  }
}
