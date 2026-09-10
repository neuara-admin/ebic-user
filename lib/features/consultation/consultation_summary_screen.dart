import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class ConsultationSummaryScreen extends StatelessWidget {
  final ConsultationModel consultation;

  const ConsultationSummaryScreen({super.key, required this.consultation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Consultation Summary'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Consultation Info Header
              EbicCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Icon(Icons.medical_services, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                consultation.dietitianName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                consultation.dietitianSpecialization ?? 'Clinical Dietitian',
                                style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date & Time', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(consultation.scheduledAt),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Member', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                        Text(
                          consultation.memberName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Clinical Notes (Section 21)
              const Text(
                'Clinical Dietitian Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              EbicCard(
                child: Text(
                  consultation.summary ??
                      consultation.notes ??
                      'Patient shows consistent adherence to complex carbohydrate goals. Recommended increasing lean protein intake to 1.4g/kg body weight and maintaining 3.5L daily hydration. Diet plan updated with low-GI breakfast recipes and evening herbal infusions.',
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),

              // Key Goals
              const Text(
                'Assigned Focus Areas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              EbicCard(
                child: Column(
                  children: [
                    _buildGoalRow(Icons.local_dining, 'Increase Lean Protein', 'Target 75g daily'),
                    const Divider(height: 16),
                    _buildGoalRow(Icons.water_drop_outlined, 'Hydration Target', '3.2 Litres daily'),
                    const Divider(height: 16),
                    _buildGoalRow(Icons.nightlight_round, 'Dinner Cutoff', 'Complete dinner by 8:30 PM'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              EbicButton(
                label: 'View Updated Diet Plan',
                icon: Icons.restaurant_menu_rounded,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.dietPlan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
