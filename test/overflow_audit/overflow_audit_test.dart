// Layout audit: opens every route with real backend data and re-lays it out on
// several device profiles, recording RenderFlex overflows (with the source
// location of the overflowing widget) and runtime exceptions.
//
// Needs the local backend running and a config file with a customer token:
//   flutter test test/overflow_audit --dart-define=AUDIT_CONFIG=<path to audit_config.json>
// Results: build/overflow_audit/user.jsonl
@Tags(['audit'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ebic_user/core/auth/auth_service.dart';
import 'package:ebic_user/core/config/app_config.dart';
import 'package:ebic_user/core/routing/app_router.dart';
import 'package:ebic_user/shared/widgets/responsive_app_frame.dart';
import 'package:ebic_user/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audit_fonts.dart';

const _configPath = String.fromEnvironment('AUDIT_CONFIG');
const _onlyRoute = String.fromEnvironment('AUDIT_ROUTE');
const _fontsDir = String.fromEnvironment('AUDIT_FONTS');

class _Profile {
  final String name;
  final Size size;
  final double dpr;
  final double textScale;
  const _Profile(this.name, this.size, this.dpr, [this.textScale = 1.0]);
}

const _profiles = [
  _Profile('phone-360', Size(360, 780), 2),
  _Profile('small-320', Size(320, 640), 2),
  _Profile('large-412', Size(412, 915), 2.625),
  _Profile('tablet-800', Size(800, 1280), 2),
  _Profile('bigtext-360@1.3x', Size(360, 780), 2, 1.3),
];

final _locationRe = RegExp(r'file:///\S*?/lib/(\S+?\.dart):(\d+):(\d+)');
final _overflowRe = RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)');

bool _isIgnorableError(String s) =>
    s.contains('MissingPluginException') ||
    s.contains('SocketException') ||
    s.contains('HTTP request failed') ||
    s.contains('NetworkImage') ||
    s.contains('ImageCodecException') ||
    s.contains('google_fonts') ||
    s.contains('allowRuntimeFetching') ||
    s.contains('PlatformException') ||
    s.contains('Unable to load asset');

void main() {
  if (_configPath.isEmpty) {
    test('overflow audit (skipped: no AUDIT_CONFIG)', () {}, skip: true);
    return;
  }
  final cfg = jsonDecode(File(_configPath).readAsStringSync()) as Map<String, dynamic>;
  final customer = cfg['customer'] as Map<String, dynamic>;
  final ids = cfg['ids'] as Map<String, dynamic>;

  final routes = RegExp(r"static const String \w+\s*=\s*'([^']+)'")
      .allMatches(File('lib/core/routing/app_routes.dart').readAsStringSync())
      .map((m) => m[1]!)
      .where((r) => _onlyRoute.isEmpty || r == _onlyRoute)
      .toSet()
      .toList();

  final out = File('build/overflow_audit/user.jsonl');

  // One generic argument map; each route reads the keys it needs.
  final args = <String, dynamic>{
    'orderId': ids['activeOrderId'],
    'memberId': ids['memberId'],
    'id': ids['activeOrderId'],
    'phone': customer['phone'],
    'purpose': 'LOGIN',
    'name': customer['name'],
  };

  setUpAll(() async {
    HttpOverrides.global = null; // allow real HTTP to the local backend
    AppConfig.apiBaseUrl = cfg['apiBaseUrl'] as String;
    await loadAuditFonts(_fontsDir); // real font metrics, no runtime fetching
    SharedPreferences.setMockInitialValues({
      'ebic_access_token': customer['token'],
      'ebic_auth_user_id': customer['userId'],
      'ebic_auth_user_phone': customer['phone'],
      'ebic_auth_user_name': customer['name'],
      if (ids['memberId'] != null) 'ebic_auth_active_member_id': ids['memberId'],
      'onboarding_completed': true,
    });
    await AuthService().initialize();
    if (_onlyRoute.isEmpty || !out.existsSync()) {
      out.createSync(recursive: true);
      out.writeAsStringSync('');
    }
  });

  for (final route in routes) {
    testWidgets('audit $route', (tester) async {
      final overflows = <String, Map<String, dynamic>>{};
      final errors = <String>{};
      var currentProfile = _profiles.first.name;

      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.toString();
        if (text.contains('overflowed by')) {
          final loc = _locationRe.firstMatch(text);
          final ov = _overflowRe.firstMatch(text);
          final key = loc != null ? '${loc[1]}:${loc[2]}' : text.split('\n').first;
          final entry = overflows.putIfAbsent(key, () => {
                'location': key,
                'by': ov?[1],
                'edge': ov?[2],
                'profiles': <String>[],
              });
          final profiles = entry['profiles'] as List<String>;
          if (!profiles.contains(currentProfile)) profiles.add(currentProfile);
        } else if (!_isIgnorableError(text)) {
          final loc = _locationRe.firstMatch(text);
          errors.add('${details.exceptionAsString().split('\n').first}'
              '${loc != null ? ' @ ${loc[1]}:${loc[2]}' : ''}');
        }
      };

      Future<void> settle(int rounds) async {
        for (var i = 0; i < rounds; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      Future<void> scrollEverything() async {
        final scrollables = find.byType(Scrollable);
        final count = scrollables.evaluate().length;
        for (var i = 0; i < count && i < 6; i++) {
          final finder = scrollables.at(i);
          if (finder.evaluate().isEmpty) continue;
          final state = tester.state<ScrollableState>(finder);
          final pos = state.position;
          if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) continue;
          for (var step = 0; step < 12 && pos.pixels < pos.maxScrollExtent; step++) {
            pos.jumpTo((pos.pixels + pos.viewportDimension * 0.8).clamp(0, pos.maxScrollExtent));
            await tester.pump(const Duration(milliseconds: 50));
          }
          pos.jumpTo(0);
          await tester.pump();
        }
      }

      // Native views (Google Maps) can't exist in tests: answer the platform
      // view channel so they lay out as empty boxes.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        switch (call.method) {
          case 'create':
            return 1;
          case 'resize':
            final a = call.arguments as Map;
            return {'width': a['width'], 'height': a['height']};
          default:
            return null;
        }
      });

      // Plugin calls without a native side fail asynchronously; record them
      // instead of letting them abort the audit of this route.
      final done = Completer<void>();
      runZonedGuarded(() async {
        try {
          final first = _profiles.first;
          tester.view.physicalSize = first.size * first.dpr;
          tester.view.devicePixelRatio = first.dpr;

          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            onGenerateInitialRoutes: (_) => [
              AppRouter.onGenerateRoute(RouteSettings(name: route, arguments: args)),
            ],
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) => ResponsiveAppFrame(child: child),
          ));
          await settle(6); // let real network load

          for (final profile in _profiles) {
            currentProfile = profile.name;
            tester.view.physicalSize = profile.size * profile.dpr;
            tester.view.devicePixelRatio = profile.dpr;
            tester.platformDispatcher.textScaleFactorTestValue = profile.textScale;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await scrollEverything();
          }
        } catch (e) {
          errors.add('BUILD: ${e.toString().split('\n').first}');
        } finally {
          done.complete();
        }
      }, (error, stack) {
        final s = error.toString();
        if (!_isIgnorableError(s)) {
          final loc = _locationRe.firstMatch(stack.toString());
          errors.add('ASYNC: ${s.split('\n').first}${loc != null ? ' @ ${loc[1]}:${loc[2]}' : ''}');
        }
      });
      await done.future;

      try {
        // nothing: results are written below
      } finally {
        FlutterError.onError = previous;
        out.writeAsStringSync(
          '${jsonEncode({'route': route, 'overflows': overflows.values.toList(), 'errors': errors.toList()})}\n',
          mode: FileMode.append,
        );
        // Dispose the tree and flush pending timers (API client request
        // timeouts are 15 s on the fake clock)
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 30));
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        // Swallow leftover async errors from screens; they are recorded above.
        while (tester.takeException() != null) {}
      }
    });
  }
}
