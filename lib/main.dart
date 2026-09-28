import 'package:flutter/material.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'core/realtime/realtime_notification_banner.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shared/widgets/responsive_app_frame.dart';

void main() async {
  await AppBootstrap.initialize();
  runApp(const EbicCustomerApp());
}

class EbicCustomerApp extends StatelessWidget {
  final String initialRoute;
  final Widget? home;

  const EbicCustomerApp({
    super.key,
    this.initialRoute = AppRoutes.splash,
    this.home,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController();

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: AppKeys.navigatorKey,
          scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
          title: 'Ebic',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          home: home,
          initialRoute: home == null ? initialRoute : null,
          onGenerateInitialRoutes: home == null
              ? (String initialRouteName) {
                  return [AppRouter.onGenerateRoute(RouteSettings(name: initialRouteName))];
                }
              : null,
          onGenerateRoute: AppRouter.onGenerateRoute,
          // Font-size cap + tablet width cap for every screen, dialog and sheet
          builder: (context, child) => ResponsiveAppFrame(child: child),
        );
      },
    );
  }
}
