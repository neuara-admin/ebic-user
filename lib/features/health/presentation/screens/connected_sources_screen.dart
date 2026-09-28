import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ebic_button.dart';
import '../../integrations/health_provider_manager.dart';

class ConnectedSourcesScreen extends StatefulWidget {
  const ConnectedSourcesScreen({super.key});

  @override
  State<ConnectedSourcesScreen> createState() => _ConnectedSourcesScreenState();
}

class _ConnectedSourcesScreenState extends State<ConnectedSourcesScreen> {
  final HealthProviderManager _manager = HealthProviderManager();

  @override
  void initState() {
    super.initState();
    _manager.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Connected Health Sources',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: () => _manager.refresh(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _manager,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Connect your health platforms once to automatically sync activity, sleep, weight, and vitals with your EBIC nutrition plan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF065F46),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? 'AVAILABLE PROVIDERS (iOS)'
                      : (defaultTargetPlatform == TargetPlatform.android
                          ? 'AVAILABLE PROVIDERS (ANDROID)'
                          : 'AVAILABLE PROVIDERS'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // iOS: Apple Health
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  _buildProviderCard(
                    provider: HealthProviderEnum.appleHealth,
                    icon: Icons.health_and_safety_rounded,
                    iconColor: const Color(0xFFEF4444),
                    iconBg: const Color(0xFFFEE2E2),
                  ),
                  const SizedBox(height: 14),
                ],

                // Android: Health Connect. This is the one real integration
                // point on Android — Samsung Health, Google Fit successors,
                // and most wearable apps all write into Health Connect
                // rather than exposing their own sync API, so there is
                // nothing distinct to "connect" separately for them.
                if (defaultTargetPlatform == TargetPlatform.android ||
                    (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android)) ...[
                  _buildProviderCard(
                    provider: HealthProviderEnum.healthConnect,
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFD1FAE5),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 18),

                // Actions Section
                const Divider(),
                const SizedBox(height: 20),

                if (_manager.isSyncing) ...[
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          _manager.syncStatusMessage ?? 'Syncing health data...',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.slate600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  EbicButton(
                    label: 'Sync All Sources Now',
                    icon: Icons.sync_rounded,
                    onPressed: () async {
                      final connected = HealthProviderEnum.values.where(_manager.isConnected);
                      if (connected.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No health sources are connected yet.')),
                        );
                        return;
                      }
                      var allOk = true;
                      for (final p in connected) {
                        final ok = await _manager.syncNow(p);
                        allOk = allOk && ok;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: allOk ? AppColors.primaryDark : AppColors.danger,
                            content: Text(
                              allOk
                                  ? 'Health data synced from your device.'
                                  : _manager.lastError ?? 'Some sources failed to sync.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.slate300),
                    ),
                    icon: const Icon(Icons.security_rounded, size: 18, color: AppColors.slate700),
                    label: const Text(
                      'Manage Health Permissions',
                      style: TextStyle(color: AppColors.slate800, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showPermissionsDialog(),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runAndReport(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(_manager.lastError ?? 'Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Widget _buildProviderCard({
    required HealthProviderEnum provider,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    final isConnected = _manager.isConnected(provider);
    final lastSync = _manager.getLastSync(provider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? const Color(0xFF10B981).withValues(alpha: 0.3) : AppColors.slate200,
          width: isConnected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isConnected) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Connected',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (lastSync != null) ...[
                            Text(
                              ' • Last Sync: $lastSync',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Not Connected',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.slate600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isConnected) ...[
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Disconnect ${provider.displayName}?'),
                        content: const Text(
                          'Stopping synchronization will prevent future automatic health data imports. Past synchronized metrics remain saved in your account.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _manager.disconnect(provider);
                    }
                  },
                  child: const Text('Disconnect', style: TextStyle(color: AppColors.danger)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync Now'),
                  onPressed: () => _runAndReport(() => _manager.syncNow(provider)),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _runAndReport(() => _manager.connect(provider)),
                  child: const Text('Connect Provider'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'EBIC only requests read access to metrics required for personalizing your meal plan and monitoring your health progress.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 20),
              _buildPermissionRow('Daily Step Count & Activity', true),
              _buildPermissionRow('Active Calories Burned', true),
              _buildPermissionRow('Sleep Duration & Resting Heart Rate', true),
              _buildPermissionRow('Body Weight & Composition', true),
              _buildPermissionRow('Hydration & Water Intake', true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionRow(String title, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
