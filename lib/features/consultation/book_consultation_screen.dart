import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class BookConsultationScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const BookConsultationScreen({super.key, this.arguments});

  @override
  State<BookConsultationScreen> createState() => _BookConsultationScreenState();
}

class _BookConsultationScreenState extends State<BookConsultationScreen> {
  final ApiClient _api = ApiClient();
  DietitianModel? _selectedDietitian;
  List<HouseholdMemberModel> _householdMembers = [];
  String? _selectedMemberId;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00 AM';

  bool _isLoadingMembers = true;
  bool _isBooking = false;
  String? _errorMessage;

  final List<String> _slots = [
    '09:00 AM',
    '10:00 AM',
    '11:30 AM',
    '02:00 PM',
    '04:00 PM',
    '05:30 PM',
    '07:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.arguments != null && widget.arguments!['dietitian'] is DietitianModel) {
      _selectedDietitian = widget.arguments!['dietitian'] as DietitianModel;
    }
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _householdMembers = list;
          if (list.isNotEmpty) {
            _selectedMemberId = list.first.id;
          }
          _isLoadingMembers = false;
        });
      } else {
        setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDietitian == null) {
      setState(() => _errorMessage = 'Please select a dietitian');
      return;
    }

    setState(() {
      _isBooking = true;
      _errorMessage = null;
    });

    try {
      // Calculate scheduledAt ISO string
      final timeParts = _selectedSlot.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      int minute = int.parse(hourMinute[1]);
      if (timeParts[1] == 'PM' && hour != 12) hour += 12;
      if (timeParts[1] == 'AM' && hour == 12) hour = 0;

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );

      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultations,
        body: {
          'dietitianId': _selectedDietitian!.id,
          'memberId': _selectedMemberId,
          'scheduledAt': scheduledDateTime.toIso8601String(),
          'consultationType': 'VIDEO',
        },
        requiresIdempotency: true,
      );

      setState(() => _isBooking = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Booking Confirmed!'),
              ],
            ),
            content: Text(
              'Your video consultation with ${_selectedDietitian!.name} is scheduled for ${DateFormat('dd MMM yyyy').format(_selectedDate)} at $_selectedSlot.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.consultationsList);
                },
                child: const Text('View My Consultations', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isBooking = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, dd MMM');

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Book Consultation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Dietitian Selection (Section 17)
              const Text('1. Clinical Dietitian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_selectedDietitian != null)
                EbicCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Icon(Icons.person, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedDietitian!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_selectedDietitian!.specialization ?? 'Clinical Nutrition', style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                )
              else
                EbicButton(
                  label: 'Choose Dietitian',
                  variant: EbicButtonVariant.outline,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.dietitian),
                ),
              const SizedBox(height: 20),

              // 2. Member Selection (Section 17: member-specific health access)
              const Text('2. For Household Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_isLoadingMembers)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _householdMembers.map((m) {
                    final isSelected = _selectedMemberId == m.id;
                    return ChoiceChip(
                      label: Text('${m.name} (${m.relationship})'),
                      selected: isSelected,
                      selectedColor: AppColors.primarySubtle,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedMemberId = m.id);
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // 3. Date Selection
              const Text('3. Select Consultation Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final date = DateTime.now().add(Duration(days: idx + 1));
                    final isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;

                    return InkWell(
                      onTap: () => setState(() => _selectedDate = date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.slate200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white70 : AppColors.slate500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 4. Time Slot Selection
              const Text('4. Select Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: AppColors.primarySubtle,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedSlot = slot);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Booking Summary
              EbicCard(
                child: Column(
                  children: [
                    _buildSummaryRow('Consultation Type', '1-on-1 HD Video Consultation'),
                    const Divider(height: 16),
                    _buildSummaryRow('Scheduled Date', dateFormat.format(_selectedDate)),
                    const Divider(height: 16),
                    _buildSummaryRow('Time Window', '$_selectedSlot (45 mins)'),
                    const Divider(height: 16),
                    _buildSummaryRow('Health Pass Benefit', 'Covered by Active Pass (₹0)', isGreen: true),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              EbicButton(
                label: 'Confirm Consultation',
                icon: Icons.video_call_outlined,
                isLoading: _isBooking,
                onPressed: _confirmBooking,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isGreen ? AppColors.primary : AppColors.slate900,
          ),
        ),
      ],
    );
  }
}
