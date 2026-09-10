import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _shareVitalsWithChef = false;
  bool _allowDietitianDocumentAccess = true;
  bool _encryptedCloudBackup = true;
  bool _personalizedRecommendations = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Privacy & Health Data Consent'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 63: Health Privacy Principle Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, color: AppColors.primaryDark, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Member-Specific Health Isolation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Every household member’s diagnostic reports, consultation summaries, and vitals are individually encrypted. Data access requires explicit member-level consent.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate800, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Consent Toggles (Section 61)
              const Text('Consent & Data Sharing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
              const SizedBox(height: 12),

              EbicCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: const Text('Clinical Dietitian Document Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Allow assigned licensed RD to view uploaded lab reports for diet formulation', style: TextStyle(fontSize: 11)),
                      value: _allowDietitianDocumentAccess,
                      onChanged: (val) => setState(() => _allowDietitianDocumentAccess = val),
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: const Text('Share Dietary Allergies with Chef', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Share only allergic restrictions (no diagnostic files) with arriving chef', style: TextStyle(fontSize: 11)),
                      value: _shareVitalsWithChef,
                      onChanged: (val) => setState(() => _shareVitalsWithChef = val),
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: const Text('Encrypted Cloud Storage & Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Store health records with AES-256 zero-knowledge encryption', style: TextStyle(fontSize: 11)),
                      value: _encryptedCloudBackup,
                      onChanged: (val) => setState(() => _encryptedCloudBackup = val),
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: const Text('Personalized Recipe Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Use nutritional requirements to curate meal catalogue recommendations', style: TextStyle(fontSize: 11)),
                      value: _personalizedRecommendations,
                      onChanged: (val) => setState(() => _personalizedRecommendations = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Rights & Data Portability
              const Text('Data Subject Rights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
              const SizedBox(height: 10),

              EbicCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                      title: const Text('Export My Health Archive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Download all consultations, vitals & records as zip', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preparing secure download package. You will receive an email link shortly.')),
                        );
                      },
                    ),
                    const Divider(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                      title: const Text('Request Health Data Erasure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger)),
                      subtitle: const Text('Permanently purge sensitive medical metrics from server', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erasure request submitted to Data Protection Officer.')),
                        );
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
