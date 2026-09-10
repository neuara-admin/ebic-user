import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class HealthPassPlansScreen extends StatefulWidget {
  const HealthPassPlansScreen({super.key});

  @override
  State<HealthPassPlansScreen> createState() => _HealthPassPlansScreenState();
}

class _HealthPassPlansScreenState extends State<HealthPassPlansScreen> {
  final ApiClient _api = ApiClient();
  List<HealthPassPlanModel> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.healthPassPlans);
      if (res.success && res.data != null) {
        setState(() {
          _plans = res.data!
              .map((json) => HealthPassPlanModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        // Fallback default plans according to Section 10 & 11 specification
        setState(() {
          _plans = [
            HealthPassPlanModel(
              id: 'plan_care_01',
              code: 'EBIC_CARE',
              name: 'EBIC Care',
              description: 'Comprehensive family clinical nutrition and priority home chef ecosystem.',
              benefits: [
                'Unlimited Dietitian consultations',
                'Personalized weekly clinical diet plans',
                'Chef-related booking benefits & allowances',
                'Family coverage (up to 4 members)',
                'Health records & lab diagnostics vault',
                'Priority dispatch routing',
              ],
            ),
            HealthPassPlanModel(
              id: 'plan_essential_01',
              code: 'EBIC_ESSENTIAL',
              name: 'EBIC Essential',
              description: 'Essential personalized nutrition guidance with on-demand chef bookings.',
              benefits: [
                '1 Dietitian consultation per month',
                'Personalized diet plan for self',
                'Standard chef booking privileges',
                'Health progress tracking',
              ],
              durationOptions: [
                HealthPassDurationOption(months: 1, label: '1 Month', priceRupees: 1499),
                HealthPassDurationOption(months: 3, label: '3 Months', priceRupees: 3999),
                HealthPassDurationOption(months: 6, label: '6 Months', priceRupees: 6999),
                HealthPassDurationOption(months: 12, label: '12 Months', priceRupees: 11999),
              ],
            ),
          ];
          _isLoading = false;
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
        title: const Text('Choose Your Health Pass'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      EbicButton(label: 'Retry', onPressed: _fetchPlans),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (ctx, idx) {
                    final plan = _plans[idx];
                    final isHighlighted = plan.code == 'EBIC_CARE';

                    return _PlanCard(
                      plan: plan,
                      isHighlighted: isHighlighted,
                      onChoose: (duration) {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.healthPassPurchase,
                          arguments: {
                            'plan': plan,
                            'duration': duration,
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  final HealthPassPlanModel plan;
  final bool isHighlighted;
  final Function(HealthPassDurationOption) onChoose;

  const _PlanCard({
    required this.plan,
    required this.isHighlighted,
    required this.onChoose,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late HealthPassDurationOption _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.plan.durationOptions.isNotEmpty
        ? widget.plan.durationOptions.first
        : HealthPassDurationOption(months: 1, label: '1 Month', priceRupees: 2999);
  }

  @override
  Widget build(BuildContext context) {
    return EbicCard(
      border: widget.isHighlighted
          ? Border.all(color: AppColors.primary, width: 2)
          : Border.all(color: AppColors.slate200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.plan.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              if (widget.isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (widget.plan.description != null) ...[
            const SizedBox(height: 6),
            Text(widget.plan.description!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ],
          const Divider(height: 24),

          // Benefits (Section 10)
          const Text('Included Benefits:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800)),
          const SizedBox(height: 8),
          ...widget.plan.benefits.map((b) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(b, style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),

          // Duration picker (1, 3, 6, 12 months)
          const Text('Select Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.plan.durationOptions.map((opt) {
              final isSelected = _selectedDuration.months == opt.months;
              return ChoiceChip(
                label: Text(opt.label),
                selected: isSelected,
                selectedColor: AppColors.primarySubtle,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedDuration = opt);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Dynamic price display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price for selected duration', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                  Text(
                    '₹${_selectedDuration.priceRupees.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              EbicButton(
                label: 'Choose Plan',
                onPressed: () => widget.onChoose(_selectedDuration),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
