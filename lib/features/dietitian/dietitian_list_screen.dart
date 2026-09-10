import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import 'dietitian_profile_screen.dart';

class DietitianListScreen extends StatefulWidget {
  const DietitianListScreen({super.key});

  @override
  State<DietitianListScreen> createState() => _DietitianListScreenState();
}

class _DietitianListScreenState extends State<DietitianListScreen> {
  final ApiClient _api = ApiClient();
  List<DietitianModel> _dietitians = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDietitians();
  }

  Future<void> _fetchDietitians() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.dietitians);
      if (res.success && res.data != null) {
        setState(() {
          _dietitians = res.data!
              .map((json) => DietitianModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message ?? 'No dietitians currently available';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Clinical Dietitians'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Consultations',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _dietitians.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      EbicButton(label: 'Retry', onPressed: _fetchDietitians),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _dietitians.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (ctx, idx) {
                    final dietitian = _dietitians[idx];
                    return _buildDietitianCard(dietitian);
                  },
                ),
    );
  }

  Widget _buildDietitianCard(DietitianModel d) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: AppColors.primary, size: 32),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.qualification ?? 'Registered Dietitian (RD)',
                      style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${d.rating}  •  ${d.experienceYears} yrs experience',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.specialization != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Focus: ${d.specialization}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate700, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Languages: ${d.languages ?? 'English, Hindi'}',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: 'View Profile',
                  variant: EbicButtonVariant.ghost,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DietitianProfileScreen(dietitian: d),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EbicButton(
                  label: 'Select Dietitian',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationBook,
                      arguments: {'dietitian': d},
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
