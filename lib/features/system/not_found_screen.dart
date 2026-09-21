import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 20 Section 320 — Not Found Screen (404 / Broken Deep Link)
class NotFoundScreen extends StatelessWidget {
  final String? message;

  const NotFoundScreen({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Page Not Found'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    color: AppColors.slate500,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "We couldn't find what you're looking for.",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'The link may be outdated, expired, or the resource has been removed.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 180,
                  child: EbicButton(
                    label: 'Go Home',
                    icon: Icons.home_rounded,
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.mainShell,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
