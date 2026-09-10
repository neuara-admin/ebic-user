import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

class ConsultationListScreen extends StatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  State<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends State<ConsultationListScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<ConsultationModel> _consultations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchConsultations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchConsultations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.consultations);
      if (res.success && res.data != null) {
        setState(() {
          _consultations = res.data!
              .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _consultations = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelConsultation(ConsultationModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Consultation?'),
        content: Text('Are you sure you want to cancel your appointment with ${c.dietitianName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Consultation', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultationCancel(c.id),
        body: {'reason': 'Customer requested cancellation'},
      );
      _fetchConsultations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation cancelled.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _consultations.where((c) => c.status == 'SCHEDULED' || c.status == 'PENDING').toList();
    final past = _consultations.where((c) => c.status != 'SCHEDULED' && c.status != 'PENDING').toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Dietitian Consultations'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past Consultations'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConsultations,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(upcoming, isUpcoming: true),
                  _buildList(past, isUpcoming: false),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.dietitian),
      ),
    );
  }

  Widget _buildList(List<ConsultationModel> items, {required bool isUpcoming}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming ? Icons.calendar_today_outlined : Icons.history_edu_outlined,
              size: 56,
              color: AppColors.slate300,
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming consultations' : 'No past consultations found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Book an appointment with your dedicated clinical dietitian.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final c = items[idx];

        return EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(status: c.status),
                  Text(
                    c.consultationType,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                          c.dietitianName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                        ),
                        Text(
                          'For member: ${c.memberName}',
                          style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.slate400),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(c.scheduledAt),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate800),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isUpcoming) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: EbicButton(
                        label: 'Join Video Consultation',
                        icon: Icons.videocam,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.consultationVideo,
                            arguments: {'consultation': c},
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: EbicButton(
                        label: 'Cancel',
                        variant: EbicButtonVariant.outline,
                        onPressed: () => _cancelConsultation(c),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: EbicButton(
                        label: 'View Summary',
                        variant: EbicButtonVariant.ghost,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.consultationSummary,
                            arguments: {'consultation': c},
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: EbicButton(
                        label: 'View Diet Plan',
                        variant: EbicButtonVariant.outline,
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
