import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

import '../../core/theme/theme_controller.dart';

/// Module 3 — Section 32 (Sections 60–63): Customer Preferences Screen
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final ApiClient _api = ApiClient();
  final ThemeController _themeController = ThemeController();

  String _selectedLanguage = 'en';
  String _themeMode = 'system';

  bool _smsNotify = true;
  bool _whatsappNotify = true;
  bool _emailNotify = true;
  bool _pushNotify = true;

  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);

    // Local theme from ThemeController
    _themeMode = _themeController.themeModeString;

    final prefs = await LocalPreferences.getInstance();
    _selectedLanguage = 'en'; // Enforce English
    await prefs.setLanguage('en');

    try {
      // Backend sync for account-level preferences (Section 62 & 63)
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.preferences);
      if (res.success && res.data != null) {
        final data = res.data!;
        _selectedLanguage = data['language'] ?? _selectedLanguage;

        final notif = data['notificationPreferences'] as Map<String, dynamic>?;
        if (notif != null) {
          _smsNotify = notif['sms'] ?? true;
          _whatsappNotify = notif['whatsapp'] ?? true;
          _emailNotify = notif['email'] ?? true;
          _pushNotify = notif['push'] ?? true;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAccountPreferences() async {
    final prefs = await LocalPreferences.getInstance();
    await prefs.setLanguage(_selectedLanguage);

    try {
      await _api.patch<Map<String, dynamic>>(
        ApiEndpoints.preferences,
        body: {
          'language': _selectedLanguage,
          'notificationPreferences': {
            'sms': _smsNotify,
            'whatsapp': _whatsappNotify,
            'email': _emailNotify,
            'push': _pushNotify,
          },
        },
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Customer Preferences'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 61: Preferences vs Health/Diet distinction banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : AppColors.primarySubtle.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.primarySubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: isDark ? AppColors.primaryLight : AppColors.primaryDark, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These manage app language, alert delivery channels, and device display theme.',
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate200 : AppColors.primaryDark, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Language Selection (Section 60 & 63 - English Only)
                    const Text(
                      'PREFERRED LANGUAGE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    EbicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'English',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                            subtitle: const Text(
                              'English (Primary / Supported)',
                              style: TextStyle(color: AppColors.slate500, fontSize: 12),
                            ),
                            value: 'en',
                            groupValue: _selectedLanguage,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedLanguage = val);
                                _updateAccountPreferences();
                              }
                            },
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: isDark ? AppColors.slate400 : AppColors.slate500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Only English is currently supported. Additional regional languages will be available in upcoming releases.',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Communication Channels (Section 60)
                    const Text(
                      'COMMUNICATION CHANNELS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    EbicCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('WhatsApp Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Chef arrival alerts & preparation status', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                            value: _whatsappNotify,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _whatsappNotify = val);
                              _updateAccountPreferences();
                            },
                          ),
                          const Divider(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('SMS Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('One-time passwords & security PINs', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                            value: _smsNotify,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _smsNotify = val);
                              _updateAccountPreferences();
                            },
                          ),
                          const Divider(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Real-time reminders for scheduled meals', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                            value: _pushNotify,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _pushNotify = val);
                              _updateAccountPreferences();
                            },
                          ),
                          const Divider(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Email Receipts & Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Weekly nutrition summaries and invoices', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                            value: _emailNotify,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _emailNotify = val);
                              _updateAccountPreferences();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Local Device Appearance (Section 62 - Full Light, Dark & System)
                    const Text(
                      'APP APPEARANCE (DEVICE LOCAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    EbicCard(
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(Icons.brightness_auto, color: isDark ? AppColors.slate300 : AppColors.slate600),
                            title: Text('System Default', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Matches your device system dark/light mode setting', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                            value: 'system',
                            groupValue: _themeMode,
                            activeColor: AppColors.primary,
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() => _themeMode = val);
                                await _themeController.setThemeMode(val);
                              }
                            },
                          ),
                          const Divider(height: 12),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.light_mode, color: AppColors.accent),
                            title: Text('Light Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Clean crisp background with high contrast readability', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                            value: 'light',
                            groupValue: _themeMode,
                            activeColor: AppColors.primary,
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() => _themeMode = val);
                                await _themeController.setThemeMode(val);
                              }
                            },
                          ),
                          const Divider(height: 12),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.dark_mode, color: AppColors.primaryLight),
                            title: Text('Dark Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate900)),
                            subtitle: const Text('Sleek dark theme optimized for low-light environments', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                            value: 'dark',
                            groupValue: _themeMode,
                            activeColor: AppColors.primary,
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() => _themeMode = val);
                                await _themeController.setThemeMode(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
