import 'package:flutter/material.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_outlined_button.dart';

/// Module 20 Section 313 — App Update Screen
/// Supports both FORCED_UPDATE and OPTIONAL_UPDATE states per specification.
class AppUpdateScreen extends StatelessWidget {
  final bool isForced;
  final String? latestVersion;
  final String? updateUrl;
  final VoidCallback? onLater;
  final VoidCallback? onUpdate;

  const AppUpdateScreen({
    super.key,
    this.isForced = false,
    this.latestVersion,
    this.updateUrl,
    this.onLater,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final remoteConfig = RemoteConfigService();
    final version = latestVersion ?? remoteConfig.latestVersion;
    final url = updateUrl ?? remoteConfig.updateUrl;

    return WillPopScope(
      onWillPop: () async => !isForced,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    isForced
                        ? 'Please update EBIC to continue.'
                        : 'A new version of EBIC is available.',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isForced
                        ? 'To protect your account and use the latest nutrition and chef services, please update to version $version.'
                        : 'Version $version includes performance improvements and new features. Update now for the best experience.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: EbicButton(
                      label: 'Update Now',
                      icon: Icons.launch_rounded,
                      onPressed: onUpdate ??
                          () {
                            // Can open store url or trigger platform intent
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Redirecting to store: $url')),
                            );
                          },
                    ),
                  ),
                  if (!isForced) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: EBICOutlinedButton(
                        label: 'Later',
                        onPressed: onLater ?? () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
