import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../shared/models/household_member_model.dart';
import '../../domain/entities/health_progress_entity.dart';
import '../../data/repositories/health_progress_repository_impl.dart';
import 'progress_timeline_screen.dart';

class HealthProgressScreen extends StatefulWidget {
  final String? initialMemberId;

  const HealthProgressScreen({super.key, this.initialMemberId});

  @override
  State<HealthProgressScreen> createState() => _HealthProgressScreenState();
}

class _HealthProgressScreenState extends State<HealthProgressScreen> {
  final HealthProgressRepositoryImpl _repository = HealthProgressRepositoryImpl();
  final ApiClient _api = ApiClient();

  List<HouseholdMemberModel> _members = [];
  String? _selectedMemberId;
  String? _selectedMemberName;

  String _selectedPeriod = '30D'; // 7D, 30D, 90D, 1Y

  HealthProgressDashboardEntity? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .whereType<Map<String, dynamic>>()
            .map(HouseholdMemberModel.fromJson)
            .toList();

        if (mounted) {
          setState(() {
            _members = list;
            if (list.isNotEmpty) {
              final initial = widget.initialMemberId != null
                  ? list.firstWhere(
                      (m) => m.id == widget.initialMemberId,
                      orElse: () => list.first,
                    )
                  : list.first;
              _selectedMemberId = initial.id;
              _selectedMemberName = initial.name;
              _fetchDashboard();
            } else {
              _isLoading = false;
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDashboard() async {
    if (_selectedMemberId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getDashboard(
        _selectedMemberId!,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _dashboard = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _quickAddWater(double litres) async {
    if (_selectedMemberId == null) return;
    try {
      await _repository.logWaterQuick(_selectedMemberId!, litres);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added +${(litres * 1000).toInt()} ml hydration!'),
          backgroundColor: const Color(0xFF0D9488),
          duration: const Duration(seconds: 2),
        ),
      );
      _fetchDashboard();
    } catch (_) {}
  }

  Future<void> _confirmMealAdherence() async {
    if (_selectedMemberId == null) return;
    try {
      await _repository.recordMealAdherence(_selectedMemberId!, 'CONSUMED_CONFIRMED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal adherence confirmed for today!'),
          backgroundColor: Color(0xFF0D9488),
          duration: Duration(seconds: 2),
        ),
      );
      _fetchDashboard();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Progress & Insights',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (_selectedMemberName != null)
              Text(
                'Tracking: $_selectedMemberName',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0D9488),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Progress Timeline',
            onPressed: () {
              if (_selectedMemberId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProgressTimelineScreen(
                      memberId: _selectedMemberId!,
                      memberName: _selectedMemberName ?? 'Member',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0D9488),
        onRefresh: _fetchDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Household Member Selector Chips (Section 8 & 116)
              _buildMemberSelector(),
              const SizedBox(height: 14),

              // 2. Period Selector Range (Section 8 & 117)
              _buildPeriodSelector(),
              const SizedBox(height: 18),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorCard()
              else if (_dashboard != null) ...[
                // 3. Weight & Trend Card (Section 11, 12, 13)
                _buildWeightCard(_dashboard!.weight),
                const SizedBox(height: 16),

                // 4. Factual Insights Carousel/Banner (Section 31-35)
                if (_dashboard!.insights.isNotEmpty) ...[
                  _buildInsightsSection(_dashboard!.insights),
                  const SizedBox(height: 16),
                ],

                // 5. Active Goals Progress (Section 14-17)
                if (_dashboard!.goals.isNotEmpty) ...[
                  _buildGoalsSection(_dashboard!.goals),
                  const SizedBox(height: 16),
                ],

                // 6. Hydration Tracker Card (Section 21, 22)
                _buildHydrationCard(_dashboard!.hydration),
                const SizedBox(height: 16),

                // 7. Activity & Sleep Row (Section 23-26)
                Row(
                  children: [
                    Expanded(child: _buildActivityCard(_dashboard!.activity)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSleepCard(_dashboard!.sleep)),
                  ],
                ),
                const SizedBox(height: 16),

                // 8. Diet Plan Meal Adherence (Section 27-29)
                _buildMealAdherenceCard(_dashboard!.adherence),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSelector() {
    if (_members.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _members.map((member) {
          final isSelected = member.id == _selectedMemberId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    member.isSelf ? Icons.person_rounded : Icons.family_restroom_rounded,
                    size: 15,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    member.name + (member.isSelf ? ' (Me)' : ''),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF0D9488),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                if (selected && _selectedMemberId != member.id) {
                  setState(() {
                    _selectedMemberId = member.id;
                    _selectedMemberName = member.name;
                  });
                  _fetchDashboard();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'key': '7D', 'label': '7 Days'},
      {'key': '30D', 'label': '30 Days'},
      {'key': '90D', 'label': '90 Days'},
      {'key': '1Y', 'label': '1 Year'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p['key'];
          return Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedPeriod != p['key']) {
                  setState(() => _selectedPeriod = p['key']!);
                  _fetchDashboard();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeightCard(WeightProgressEntity weight) {
    String trendText = 'Stable';
    Color trendColor = const Color(0xFF64748B);
    IconData trendIcon = Icons.trending_flat_rounded;

    if (weight.trendDirection == 'DECREASING') {
      trendText = '${weight.periodChange} kg';
      trendColor = const Color(0xFF059669);
      trendIcon = Icons.trending_down_rounded;
    } else if (weight.trendDirection == 'INCREASING') {
      trendText = '+${weight.periodChange} kg';
      trendColor = const Color(0xFFDC2626);
      trendIcon = Icons.trending_up_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BODY WEIGHT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Period Trend & Distribution',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Spacer(),
              if (weight.bmi != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'BMI ${weight.bmi}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Stats Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                weight.currentValue != null ? weight.currentValue!.toStringAsFixed(1) : '—',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 4),
              Text(
                weight.unit,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (weight.hasSufficientDataForTrend)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 16, color: trendColor),
                      const SizedBox(width: 4),
                      Text(
                        trendText,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: trendColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini Data Points Bar Chart (Section 53 & 54)
          if (!weight.hasSufficientDataForTrend)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not enough data to show a trend yet. Add another weight measurement to see your history.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildMiniTrendChart(weight.points),
        ],
      ),
    );
  }

  Widget _buildMiniTrendChart(List<WeightTrendPointEntity> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final minVal = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final spread = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final normalizedHeight = ((p.value - minVal) / spread * 40) + 15;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  p.value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Container(
                  height: normalizedHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.date.length >= 5 ? p.date.substring(5) : p.date,
                  style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightsSection(List<HealthInsightEntity> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FACTUAL HEALTH INSIGHTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ...insights.map((insight) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF0D9488)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight.description,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoalsSection(List<GoalProgressItemEntity> goals) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              const Text(
                'CLINICAL GOALS PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Text(
                '${goals.length} active',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...goals.map((g) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '${g.progressPercentage}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.progressPercentage / 100.0,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: const Color(0xFF0D9488),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${g.currentValue ?? '—'} ${g.unit}  •  Target: ${g.targetValue ?? '—'} ${g.unit} (${g.direction.toLowerCase()})',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHydrationCard(HydrationProgressEntity hydration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY HYDRATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Today: ${hydration.todayLitres}L of ${hydration.targetLitres}L Target',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${hydration.percentage}%',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (hydration.percentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF0284C7),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // Quick Logging Pills (Section 21: +250ml, +500ml, +750ml)
          Row(
            children: [
              const Text('Quick Log:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              _buildQuickWaterButton('+250 ml', 0.25),
              const SizedBox(width: 6),
              _buildQuickWaterButton('+500 ml', 0.50),
              const SizedBox(width: 6),
              _buildQuickWaterButton('+750 ml', 0.75),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickWaterButton(String label, double litres) {
    return InkWell(
      onTap: () => _quickAddWater(litres),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityProgressEntity activity) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_walk_rounded, color: Color(0xFF059669), size: 18),
              const SizedBox(width: 6),
              const Text(
                'STEPS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activity.hasData ? '${activity.todaySteps ?? '—'}' : 'No steps yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            activity.hasData && activity.source != null
                ? 'Source: ${activity.source}'
                : 'Manual entry',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard(SleepProgressEntity sleep) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 6),
              const Text(
                'SLEEP',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sleep.hasData && sleep.lastNightHours != null
                ? '${sleep.lastNightHours}h'
                : 'No sleep data',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            sleep.hasData && sleep.averageHours != null
                ? 'Avg: ${sleep.averageHours}h/night'
                : 'No sleep data available yet',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildMealAdherenceCard(MealAdherenceEntity adherence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DIET PLAN ADHERENCE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '${adherence.confirmedMeals} Confirmed / ${adherence.plannedMeals} Planned',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${adherence.adherenceRatePercentage}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _confirmMealAdherence,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0D9488)),
                  label: const Text(
                    'Confirm Today\'s Meal',
                    style: TextStyle(color: Color(0xFF0D9488), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Color(0xFF991B1B)),
      ),
    );
  }
}
