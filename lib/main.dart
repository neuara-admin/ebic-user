import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/auth/auth_service.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive edge-to-edge system status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize cached session authentication tokens
  final authService = AuthService();
  await authService.initialize();

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
    return MaterialApp(
      title: 'Every Bite Counts (EBIC)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: home,
      initialRoute: home == null ? initialRoute : null,
      onGenerateInitialRoutes: home == null
          ? (String initialRouteName) {
              return [AppRouter.onGenerateRoute(RouteSettings(name: initialRouteName))];
            }
          : null,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
