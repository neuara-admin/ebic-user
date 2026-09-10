import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class DietitianProfileScreen extends StatelessWidget {
  final DietitianModel dietitian;

  const DietitianProfileScreen({super.key, required this.dietitian});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text(dietitian.name),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header profile card
              EbicCard(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person, size: 48, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dietitian.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dietitian.qualification ?? 'Senior Clinical Dietitian & RD',
                      style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${dietitian.rating} (120+ consultations)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bio
              const Text('About Dietitian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              EbicCard(
                child: Text(
                  dietitian.bio ??
                      'Specializes in lifestyle intervention, medical nutrition therapy, athletic meal planning, and metabolic conditions.',
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),

              // Specialization & Languages
              const Text('Specialization & Languages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              EbicCard(
                child: Column(
                  children: [
                    _buildRow('Primary Focus', dietitian.specialization ?? 'Clinical Nutrition'),
                    const Divider(height: 16),
                    _buildRow('Clinical Experience', '${dietitian.experienceYears} Years'),
                    const Divider(height: 16),
                    _buildRow('Spoken Languages', dietitian.languages ?? 'English, Hindi'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              EbicButton(
                label: 'Book Consultation with ${dietitian.name.split(' ').first}',
                icon: Icons.calendar_today_outlined,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.consultationBook,
                    arguments: {'dietitian': dietitian},
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900)),
      ],
    );
  }
}
