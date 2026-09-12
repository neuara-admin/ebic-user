import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../health_pass/data/health_pass_repository.dart';

/// Module 3 & 4 — Sections 17 & 35: Book Clinical Dietitian Video Consultation Screen
/// Supports multi-member family selection, dynamic dietitian choice, real-time availability slots, and zero-cost Health Pass redemption.
class BookConsultationScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const BookConsultationScreen({super.key, this.arguments});

  @override
  State<BookConsultationScreen> createState() => _BookConsultationScreenState();
}

class _BookConsultationScreenState extends State<BookConsultationScreen> {
  final ApiClient _api = ApiClient();
  final HealthPassRepository _healthPassRepo = HealthPassRepository();

  // Active Health Pass context
  ActiveHealthPassModel? _activePass;
  bool _isLoadingPass = true;

  // Dietitians
  List<DietitianModel> _allDietitians = [];
  DietitianModel? _selectedDietitian;
  bool _isLoadingDietitians = true;

  // Search & Filter state for Dietitians
  final TextEditingController _dietitianSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _dietitianSearchQuery = '';
  String _selectedDietitianCategory = 'ALL'; // 'ALL', 'MY_HUB', 'METABOLIC', 'CLINICAL', 'DIABETES', 'TOP_RATED'
  bool _isDietitianDirectoryOpen = true;

  // Family Members Selection (Multi-Member Support)
  List<CoveredMemberModel> _healthPassMembers = [];
  List<HouseholdMemberModel> _householdMembers = [];
  final Set<String> _selectedMemberIds = {};
  final Map<String, String> _memberNamesMap = {};
  bool _isLoadingMembers = true;

  // Date & Slot Selection
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<DietitianSlotModel> _allSlots = [];
  DietitianSlotModel? _selectedSlot;
  bool _isLoadingSlots = false;

  // Regional Hub Context
  String? _userHubId;
  String? _userHubName;
  String? _userHubCode;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeBooking();
  }

  @override
  void dispose() {
    _dietitianSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDates() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.offset + 260,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _initializeBooking() async {
    await Future.wait([
      _loadCustomerHub(),
      _loadActivePass(),
      _fetchHouseholdMembers(),
    ]);

    await _loadDietitians();

    // Pre-select dietitian ONLY if explicitly passed via arguments
    if (widget.arguments != null && widget.arguments!['dietitian'] is DietitianModel) {
      _selectedDietitian = widget.arguments!['dietitian'] as DietitianModel;
      _isDietitianDirectoryOpen = false;
    } else {
      // User must choose dietitian first before dates and times are shown
      _selectedDietitian = null;
      _isDietitianDirectoryOpen = true;
    }

    if (_selectedDietitian != null) {
      await _loadDietitianSlots(_selectedDietitian!.id);
    }
  }

  Future<void> _loadCustomerHub() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.addresses);
      if (res.success && res.data != null && mounted) {
        final addresses = res.data!;
        if (addresses.isNotEmpty) {
          final primary = addresses.firstWhere(
            (a) => a['isPrimary'] == true || a['isDefault'] == true,
            orElse: () => addresses.first,
          );
          final hub = primary['hub'] as Map<String, dynamic>?;
          setState(() {
            _userHubId = primary['hubId']?.toString() ?? hub?['id']?.toString();
            _userHubName = primary['hubName']?.toString() ?? hub?['name']?.toString() ?? 'Hyderabad Central Hub';
            _userHubCode = hub?['code']?.toString() ?? 'HYD-CENTRAL';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadActivePass() async {
    try {
      final pass = await _healthPassRepo.fetchCurrentPass();
      if (mounted) {
        setState(() {
          _activePass = pass;
          _isLoadingPass = false;
          if (pass != null && pass.coveredMembers.isNotEmpty) {
            _healthPassMembers = pass.coveredMembers;
            for (final m in pass.coveredMembers) {
              _memberNamesMap[m.id] = '${m.name} (${m.relationship})';
            }
            // By default, select all covered family members so the whole family is included
            _selectedMemberIds.addAll(pass.coveredMembers.map((m) => m.id));
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPass = false);
    }
  }

  Future<void> _loadDietitians() async {
    try {
      final endpoint = _userHubId != null
          ? '${ApiEndpoints.dietitians}?hubId=$_userHubId'
          : ApiEndpoints.dietitians;
      final res = await _api.get<List<dynamic>>(endpoint);
      if (res.success && res.data != null && mounted) {
        final list = res.data!
            .map((json) => DietitianModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _allDietitians = list;
          _isLoadingDietitians = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingDietitians = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDietitians = false);
    }
  }

  Future<void> _fetchHouseholdMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null && mounted) {
        final list = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _householdMembers = list;
          if (_selectedMemberIds.isEmpty && list.isNotEmpty) {
            for (final m in list) {
              _memberNamesMap[m.id] = '${m.name} (${m.relationship})';
            }
            _selectedMemberIds.addAll(list.map((m) => m.id));
          }
          _isLoadingMembers = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadDietitianSlots(String dietitianId) async {
    if (mounted) {
      setState(() {
        _isLoadingSlots = true;
        _selectedSlot = null;
        _allSlots = [];
      });
    }

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.dietitianAvailability(dietitianId));
      if (res.success && res.data != null && mounted) {
        final slots = res.data!
            .map((json) => DietitianSlotModel.fromJson(json as Map<String, dynamic>))
            .where((s) => !s.isBooked && s.startsAt.isAfter(DateTime.now()))
            .toList();

        setState(() {
          _allSlots = slots;
          _isLoadingSlots = false;

          // If current selected date has slots, select the first available one
          final dateSlots = _getSlotsForDate(_selectedDate);
          if (dateSlots.isNotEmpty) {
            _selectedSlot = dateSlots.first;
          } else if (slots.isNotEmpty) {
            // Jump to the earliest date that has slots
            _selectedDate = slots.first.startsAt;
            _selectedSlot = slots.first;
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingSlots = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  List<DietitianSlotModel> _getSlotsForDate(DateTime date) {
    return _allSlots.where((s) {
      return s.startsAt.year == date.year &&
          s.startsAt.month == date.month &&
          s.startsAt.day == date.day;
    }).toList();
  }

  List<DietitianModel> get _filteredDietitians {
    return _allDietitians.where((d) {
      if (_dietitianSearchQuery.trim().isNotEmpty) {
        final q = _dietitianSearchQuery.trim().toLowerCase();
        final nameMatches = d.name.toLowerCase().contains(q);
        final specMatches = (d.specialization ?? '').toLowerCase().contains(q);
        final qualMatches = (d.qualification ?? '').toLowerCase().contains(q);
        final langMatches = (d.languages ?? '').toLowerCase().contains(q);
        final hubMatches = (d.hubName ?? '').toLowerCase().contains(q) || (d.hubCode ?? '').toLowerCase().contains(q);
        if (!nameMatches && !specMatches && !qualMatches && !langMatches && !hubMatches) {
          return false;
        }
      }

      switch (_selectedDietitianCategory) {
        case 'MY_HUB':
          if (_userHubId != null && d.hubId != null) {
            return d.hubId == _userHubId;
          }
          if (_userHubCode != null && d.hubCode != null) {
            return d.hubCode == _userHubCode;
          }
          return true;
        case 'METABOLIC':
          return (d.specialization ?? '').toLowerCase().contains('metabolic');
        case 'CLINICAL':
          return (d.qualification ?? '').toLowerCase().contains('clinical') ||
              (d.specialization ?? '').toLowerCase().contains('clinical');
        case 'DIABETES':
          final s = (d.specialization ?? '').toLowerCase();
          return s.contains('diabetes') || s.contains('weight') || s.contains('lifestyle');
        case 'TOP_RATED':
          return d.rating >= 4.8;
        default:
          return true;
      }
    }).toList();
  }

  void _onDietitianChanged(DietitianModel dietitian) {
    setState(() {
      _selectedDietitian = dietitian;
      _isDietitianDirectoryOpen = false;
    });
    _loadDietitianSlots(dietitian.id);
  }

  void _toggleMember(String id) {
    setState(() {
      if (_selectedMemberIds.contains(id)) {
        if (_selectedMemberIds.length > 1) {
          _selectedMemberIds.remove(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one family member must attend the consultation.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _selectedMemberIds.add(id);
      }
    });
  }

  void _toggleSelectAllMembers() {
    setState(() {
      final allIds = _healthPassMembers.isNotEmpty
          ? _healthPassMembers.map((m) => m.id).toList()
          : _householdMembers.map((m) => m.id).toList();

      if (_selectedMemberIds.length == allIds.length && allIds.isNotEmpty) {
        // Keep primary/first member
        _selectedMemberIds.clear();
        _selectedMemberIds.add(allIds.first);
      } else {
        _selectedMemberIds.addAll(allIds);
      }
    });
  }

  void _proceedToReview() {
    if (_selectedDietitian == null) {
      setState(() => _errorMessage = 'Please choose a clinical dietitian.');
      return;
    }
    if (_selectedSlot == null) {
      setState(() => _errorMessage = 'Please select an appointment time slot.');
      return;
    }
    if (_selectedMemberIds.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one family member for this consultation.');
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.consultationReview,
      arguments: {
        'dietitian': _selectedDietitian,
        'slot': _selectedSlot,
        'selectedMemberIds': _selectedMemberIds.toList(),
        'memberNamesMap': _memberNamesMap,
        'activePass': _activePass,
        'userHubId': _userHubId,
        'userHubName': _userHubName,
        'userHubCode': _userHubCode,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPendingKickoff = _activePass?.isConsultationPending == true;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Book Consultation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_outlined),
            tooltip: 'My Consultations',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Notice
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 1. Consultation Kickoff Banner (When Pending)
                    if (isPendingKickoff) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppColors.slate800, AppColors.slate900]
                                : [const Color(0xFFFEF3C7), const Color(0xFFFFFBEB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.stars_rounded, color: Color(0xFFB45309), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Step 1: Consultation Kickoff',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                        ),
                                      ),
                                      Text(
                                        'FREE',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Completing your initial consultation commences your ${_activePass?.durationMonths ?? 1}-month subscription countdown. Included at ₹0 with your pass.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.slate300 : const Color(0xFF78350F),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else if (_activePass != null) ...[
                      // Active Pass Allowance Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_activePass!.planName} • ${_activePass!.consultationsRemaining} Consultations Remaining',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('₹0', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // 2. Family Members Multi-Selection
                    Builder(
                      builder: (context) {
                        final totalAvailable = _healthPassMembers.isNotEmpty
                            ? _healthPassMembers.length
                            : _householdMembers.length;
                        final allSelected = totalAvailable > 0 && _selectedMemberIds.length == totalAvailable;
                        return _buildSectionHeaderWithAction(
                          '1. Attending Family Members',
                          'Select one or multiple covered members for this video session',
                          allSelected ? 'Reset to Primary' : 'Select All ($totalAvailable)',
                          _toggleSelectAllMembers,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildFamilyMembersSelector(isDark),
                    const SizedBox(height: 20),

                    // 3. Clinical Dietitian Selection
                    _buildSectionHeaderWithAction(
                      '2. Choose Clinical Dietitian',
                      _selectedDietitian != null
                          ? 'Assigned specialist for this session'
                          : 'Select your clinical nutritionist from our verified network',
                      _selectedDietitian != null
                          ? (_isDietitianDirectoryOpen ? 'Hide Directory' : 'Change Doctor')
                          : (_isDietitianDirectoryOpen ? 'Showing Directory' : 'Browse All'),
                      () {
                        setState(() {
                          _isDietitianDirectoryOpen = !_isDietitianDirectoryOpen;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDietitianSelectorSection(isDark),
                    const SizedBox(height: 22),

                    if (_selectedDietitian == null) ...[
                      // Helpful notice explaining dates and times appear after selecting a doctor
                      _buildSelectDietitianFirstNotice(isDark),
                      const SizedBox(height: 20),
                    ] else ...[
                      // 4. Date Selection (Explicitly connected to Dietitian)
                      _buildSectionHeader(
                        '3. Select Appointment Date',
                        'Available consultation dates for Dr. ${_selectedDietitian!.name} (Green indicates open slots)',
                      ),
                      const SizedBox(height: 10),
                      _buildDateSelectorStrip(isDark),
                      const SizedBox(height: 22),

                      // 5. Time Slot Selection (Explicitly connected to Dietitian)
                      _buildSectionHeader(
                        '4. Select Time Slot',
                        '45-minute 1-on-1 / family HD video call with Dr. ${_selectedDietitian!.name}',
                      ),
                      const SizedBox(height: 10),
                      _buildSlotPicker(isDark),
                      const SizedBox(height: 24),

                      // 6. Selected Slot Preview (De-cluttered Step 1)
                      if (_selectedSlot != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dr. ${_selectedDietitian!.name}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DateFormat('EEEE, dd MMM').format(_selectedSlot!.startsAt)} • ${DateFormat('hh:mm a').format(_selectedSlot!.startsAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedMemberIds.length} attending member${_selectedMemberIds.length == 1 ? '' : 's'} selected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA: Proceed to Review & Confirm
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: _selectedDietitian == null
                        ? 'Select Clinical Dietitian'
                        : _selectedSlot == null
                            ? 'Select Appointment Slot'
                            : _selectedMemberIds.isEmpty
                                ? 'Select Attending Member'
                                : 'Proceed to Review & Confirm',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: (_selectedDietitian == null ||
                            _selectedSlot == null ||
                            _selectedMemberIds.isEmpty)
                        ? null
                        : _proceedToReview,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
      ],
    );
  }

  Widget _buildSectionHeaderWithAction(String title, String subtitle, String actionLabel, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onAction,
          child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildFamilyMembersSelector(bool isDark) {
    if (_isLoadingMembers && _isLoadingPass) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_healthPassMembers.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _healthPassMembers.map((m) {
          final isSelected = _selectedMemberIds.contains(m.id);

          return InkWell(
            onTap: () => _toggleMember(m.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primarySubtle)
                    : (isDark ? AppColors.slate800 : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.slate700 : AppColors.slate200),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: isSelected ? AppColors.primary : AppColors.slate400,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          if (m.isPrimary) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
                          ],
                        ],
                      ),
                      Text(
                        m.relationship,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected ? AppColors.primaryDark : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    // Fallback for general household members
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _householdMembers.map((m) {
        final isSelected = _selectedMemberIds.contains(m.id);
        return FilterChip(
          label: Text('${m.name} (${m.relationship})'),
          selected: isSelected,
          selectedColor: AppColors.primarySubtle,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primaryDark : AppColors.slate700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          onSelected: (_) => _toggleMember(m.id),
        );
      }).toList(),
    );
  }

  Widget _buildSelectDietitianFirstNotice(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800.withOpacity(0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select a Clinical Dietitian to View Schedule',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Each specialist maintains independent clinical hours. Once you choose your preferred clinical nutritionist above, their live available dates and time slots will appear here instantly.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDietitianSelectorSection(bool isDark) {
    if (_isLoadingDietitians) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_allDietitians.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(
          children: [
            const Icon(Icons.person_off_outlined, color: AppColors.slate400, size: 32),
            const SizedBox(height: 8),
            const Text('No clinical dietitians currently available.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _loadDietitians,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // When a doctor is selected and directory is not explicitly opened, show the selected hero card
    if (_selectedDietitian != null && !_isDietitianDirectoryOpen) {
      return _buildSelectedDietitianHero(isDark);
    }

    return _buildDietitianDirectory(isDark);
  }

  Widget _buildSelectedDietitianHero(bool isDark) {
    final d = _selectedDietitian!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                    backgroundImage: d.photoUrl != null ? NetworkImage(d.photoUrl!) : null,
                    child: d.photoUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dr. ${d.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.qualification ?? 'Clinical Nutritionist (RD)',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            d.specialization ?? 'Metabolic Nutrition',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 10, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                d.hubName ?? 'Hyderabad Central Hub',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.slate600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 3),
              Text(
                '${d.rating}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${d.experienceYears}+ Yrs Experience',
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '• ${d.languages ?? "English, Hindi"}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isLoadingSlots
                      ? 'Checking live calendar...'
                      : _allSlots.isNotEmpty
                          ? '${_allSlots.length} available slots this week'
                          : 'No open slots this week',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _allSlots.isNotEmpty ? const Color(0xFF047857) : AppColors.slate500,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change Doctor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _isDietitianDirectoryOpen = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _scrollToDates,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Selected (View Available Dates Below ↓)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietitianDirectory(bool isDark) {
    final filtered = _filteredDietitians;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Regional Hub Banner
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Regional Care Hub: ${_userHubName ?? "Hyderabad Central Hub"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _userHubCode ?? 'HYD-CENTRAL',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Search Input
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _dietitianSearchController,
            onChanged: (val) {
              setState(() => _dietitianSearchQuery = val);
            },
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
            decoration: InputDecoration(
              hintText: 'Search doctor, specialty, language, or hub...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.slate400),
              suffixIcon: _dietitianSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                      onPressed: () {
                        _dietitianSearchController.clear();
                        setState(() => _dietitianSearchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Categories Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All Doctors (${_allDietitians.length})', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('MY_HUB', '📍 ${_userHubCode ?? "My Hub"}', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('METABOLIC', 'Metabolic Health', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('CLINICAL', 'Clinical Nutrition', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('DIABETES', 'Diabetes & Weight', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('TOP_RATED', '⭐ 4.8+ Rated', isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // If user already has a selected doctor and is viewing directory, show option to collapse
        if (_selectedDietitian != null) ...[
          InkWell(
            onTap: () => setState(() => _isDietitianDirectoryOpen = false),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Currently Selected: Dr. ${_selectedDietitian!.name}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Keep & Close ✕',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Vertical List of Doctors
        if (filtered.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 32, color: AppColors.slate400),
                const SizedBox(height: 8),
                const Text(
                  'No clinical dietitians match your search or filter.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _dietitianSearchController.clear();
                    setState(() {
                      _dietitianSearchQuery = '';
                      _selectedDietitianCategory = 'ALL';
                    });
                  },
                  child: const Text('Reset Search & Filters'),
                ),
              ],
            ),
          ),
        ] else ...[
          ...filtered.map((d) => _buildDietitianCard(d, isDark)),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedDietitianCategory == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDietitianCategory = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.slate800 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.slate300 : AppColors.slate700),
          ),
        ),
      ),
    );
  }

  Widget _buildDietitianCard(DietitianModel d, bool isDark) {
    final isSelected = _selectedDietitian?.id == d.id;

    return InkWell(
      onTap: () => _onDietitianChanged(d),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryDark.withOpacity(0.25) : AppColors.primarySubtle)
              : (isDark ? AppColors.slate900 : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                      backgroundImage: d.photoUrl != null ? NetworkImage(d.photoUrl!) : null,
                      child: d.photoUrl == null
                          ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Dr. ${d.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.primary, size: 15),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.qualification ?? 'Clinical Nutritionist (RD)',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              d.specialization ?? 'Metabolic Nutrition',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 10, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Text(
                                  d.hubName ?? 'Hyderabad Central Hub',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.slate600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 3),
                Text(
                  '${d.rating}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${d.experienceYears}+ Yrs Experience',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '• ${d.languages ?? "English, Hindi"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? const Color(0xFF047857)
                      : (isDark ? AppColors.primaryDark : AppColors.primary),
                  foregroundColor: Colors.white,
                  elevation: isSelected ? 1.5 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (isSelected) {
                    setState(() => _isDietitianDirectoryOpen = false);
                    _scrollToDates();
                  } else {
                    _onDietitianChanged(d);
                    _scrollToDates();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.event_available_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isSelected
                            ? 'Selected (View Available Dates Below ↓)'
                            : 'Select Clinical Dietitian',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isSelected ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorStrip(bool isDark) {
    final now = DateTime.now();

    // Height 92 gives comfortable space for Day (9.5), Gap (2), Date (16.5), Gap (2), Month (9.5), Gap (3), Slot Badge (12)
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final date = now.add(Duration(days: idx + 1));
          final isSelected = _selectedDate.year == date.year &&
              _selectedDate.month == date.month &&
              _selectedDate.day == date.day;

          final availableSlotsCount = _getSlotsForDate(date).length;

          String dayLabel = DateFormat('EEE').format(date).toUpperCase();
          if (idx == 0) dayLabel = 'TOMORROW';

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDate = date;
                final dateSlots = _getSlotsForDate(date);
                if (dateSlots.isNotEmpty) {
                  _selectedSlot = dateSlots.first;
                } else {
                  _selectedSlot = null;
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.slate800 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.slate700 : AppColors.slate200),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabel,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                      color: isSelected ? Colors.white70 : AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.slate900),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (availableSlotsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$availableSlotsCount open',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF047857),
                        ),
                      ),
                    )
                  else
                    Text(
                      'No slots',
                      style: TextStyle(
                        fontSize: 8,
                        color: isSelected ? Colors.white60 : AppColors.slate400,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotPicker(bool isDark) {
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 10),
              Text('Fetching available appointment slots...', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
            ],
          ),
        ),
      );
    }

    final dateSlots = _getSlotsForDate(_selectedDate);

    if (dateSlots.isEmpty) {
      // Find the next date with open slots
      DietitianSlotModel? nextSlot;
      for (final s in _allSlots) {
        if (s.startsAt.isAfter(_selectedDate)) {
          nextSlot = s;
          break;
        }
      }
      nextSlot ??= _allSlots.firstOrNull;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded, color: AppColors.slate400, size: 36),
            const SizedBox(height: 8),
            Text(
              'No slots open on ${DateFormat('EEE, dd MMM').format(_selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Dr. ${_selectedDietitian?.name ?? 'Dietitian'} is fully booked on this date.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
            if (nextSlot != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Flexible(
                  child: Text(
                    'Jump to ${DateFormat('EEE, dd MMM').format(nextSlot.startsAt)} (${_getSlotsForDate(nextSlot.startsAt).length} slots)',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedDate = nextSlot!.startsAt;
                    _selectedSlot = nextSlot;
                  });
                },
              ),
            ],
          ],
        ),
      );
    }

    // Group slots by Morning / Afternoon / Evening
    final morning = dateSlots.where((s) => s.startsAt.hour < 12).toList();
    final afternoon = dateSlots.where((s) => s.startsAt.hour >= 12 && s.startsAt.hour < 16).toList();
    final evening = dateSlots.where((s) => s.startsAt.hour >= 16).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morning.isNotEmpty) _buildSlotGroup('🌅 Morning Slots (09:00 AM – 12:00 PM)', morning, isDark),
        if (afternoon.isNotEmpty) _buildSlotGroup('☀️ Afternoon Slots (12:00 PM – 04:00 PM)', afternoon, isDark),
        if (evening.isNotEmpty) _buildSlotGroup('🌆 Evening Slots (04:00 PM – 08:00 PM)', evening, isDark),
      ],
    );
  }

  Widget _buildSlotGroup(String groupTitle, List<DietitianSlotModel> slots, bool isDark) {
    final timeFormat = DateFormat('hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            groupTitle,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((s) {
            final isSelected = _selectedSlot?.id == s.id;
            final isBooked = s.isBooked;

            if (isBooked) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800.withOpacity(0.5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block_rounded, size: 12, color: AppColors.slate400),
                    const SizedBox(width: 5),
                    Text(
                      '${timeFormat.format(s.startsAt)} – ${timeFormat.format(s.endsAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Booked',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate500),
                      ),
                    ),
                  ],
                ),
              );
            }

            return InkWell(
              onTap: () => setState(() => _selectedSlot = s),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySubtle
                      : (isDark ? AppColors.slate800 : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.slate700 : const Color(0xFF10B981)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.access_time_rounded,
                      size: 13,
                      color: isSelected ? AppColors.primaryDark : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${timeFormat.format(s.startsAt)} – ${timeFormat.format(s.endsAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryDark
                            : (isDark ? Colors.white : AppColors.slate800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.15) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSelected ? 'Selected' : 'Available',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primaryDark : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
