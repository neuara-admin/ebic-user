import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/local_preferences.dart';
import '../../shared/models/household_member_model.dart';

/// Module 3 — Section 37: Member Context State machine
enum MemberContextState {
  noMemberSelected,
  loadingMembers,
  membersLoaded,
  memberSelected,
  switchingMember,
  memberSelectionFailed,
}

/// Module 3 — Section 28 & 74: Centralized Member-Context Controller / Service
///
/// Features consume this singleton rather than maintaining isolated member states.
/// It encapsulates:
/// - Authoritative active member selection
/// - Default member assignment (Section 38)
/// - Local persistence across app restarts (Section 39)
/// - Rapid switching race condition protection (Section 36 & 87)
/// - Scoped cache key generation (Section 76)
class MemberContext extends ChangeNotifier {
  static final MemberContext _instance = MemberContext._internal();
  factory MemberContext() => _instance;
  MemberContext._internal();

  final ApiClient _api = ApiClient();

  List<HouseholdMemberModel> _members = [];
  HouseholdMemberModel? _selectedMember;
  MemberContextState _state = MemberContextState.noMemberSelected;
  String? _errorMessage;

  // Rapid switching guard (Section 36 & 87)
  int _switchSequence = 0;

  // Getters
  List<HouseholdMemberModel> get members => List.unmodifiable(_members);
  HouseholdMemberModel? get selectedMember => _selectedMember;
  String? get selectedMemberId => _selectedMember?.id;
  MemberContextState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading =>
      _state == MemberContextState.loadingMembers ||
      _state == MemberContextState.switchingMember;
  bool get hasSelectedMember => _selectedMember != null;

  /// Loads household members from the authoritative backend (Section 18 & 74).
  /// Enforces default member selection policy (Section 38 & 39).
  Future<void> loadMembers({bool forceRefresh = false}) async {
    if (_state == MemberContextState.loadingMembers && !forceRefresh) return;

    _state = MemberContextState.loadingMembers;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        _members = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _state = MemberContextState.membersLoaded;

        if (_members.isEmpty) {
          _selectedMember = null;
          _state = MemberContextState.noMemberSelected;
        } else {
          await _resolveDefaultOrPersistedMember();
        }
      } else {
        _state = MemberContextState.memberSelectionFailed;
        _errorMessage = res.message ?? 'Failed to load household members.';
      }
    } catch (e) {
      _state = MemberContextState.memberSelectionFailed;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Sets members directly (e.g. for unit tests or mocked data)
  void setMembersForTesting(List<HouseholdMemberModel> testMembers) {
    _members = List.from(testMembers);
    if (_members.isNotEmpty) {
      _resolveDefaultOrPersistedMemberSync();
    } else {
      _selectedMember = null;
      _state = MemberContextState.noMemberSelected;
    }
    notifyListeners();
  }

  /// Section 38 & 39: Resolves default member:
  /// 1. Stored last_selected_member_id if still present in members list.
  /// 2. Member with isSelf == true (Account Owner).
  /// 3. First member in list.
  Future<void> _resolveDefaultOrPersistedMember() async {
    final prefs = await LocalPreferences.getInstance();
    final persistedId = prefs.lastSelectedMemberId;

    HouseholdMemberModel? candidate;
    if (persistedId != null && persistedId.isNotEmpty) {
      candidate = _members.cast<HouseholdMemberModel?>().firstWhere(
            (m) => m?.id == persistedId,
            orElse: () => null,
          );
    }

    // Fallback 1: isSelf
    candidate ??= _members.cast<HouseholdMemberModel?>().firstWhere(
          (m) => m?.isSelf == true,
          orElse: () => null,
        );

    if (candidate == null && _members.isNotEmpty) {
      // Fallback 2: first member
      candidate = _members.first;
    }

    _selectedMember = candidate;
    _state = candidate != null
        ? MemberContextState.memberSelected
        : MemberContextState.noMemberSelected;

    if (candidate != null) {
      await prefs.setLastSelectedMemberId(candidate.id);
    }
  }

  void _resolveDefaultOrPersistedMemberSync() {
    HouseholdMemberModel? candidate = _members.cast<HouseholdMemberModel?>().firstWhere(
          (m) => m?.isSelf == true,
          orElse: () => _members.isNotEmpty ? _members.first : null,
        );
    _selectedMember = candidate;
    _state = candidate != null
        ? MemberContextState.memberSelected
        : MemberContextState.noMemberSelected;
  }

  /// Section 28, 35, 36 & 87: Switches active member with sequence protection
  /// against race conditions during rapid switching.
  Future<bool> selectMember(String memberId) async {
    final currentSeq = ++_switchSequence;

    _state = MemberContextState.switchingMember;
    notifyListeners();

    // Verify member exists in account's household
    final target = _members.cast<HouseholdMemberModel?>().firstWhere(
          (m) => m?.id == memberId,
          orElse: () => null,
        );

    if (target == null) {
      _state = MemberContextState.memberSelectionFailed;
      _errorMessage = 'Member not found in current household.';
      notifyListeners();
      return false;
    }

    // Rapid switching guard: if sequence has advanced, discard this stale completion
    if (currentSeq != _switchSequence) {
      return false;
    }

    _selectedMember = target;
    _state = MemberContextState.memberSelected;
    _errorMessage = null;

    final prefs = await LocalPreferences.getInstance();
    await prefs.setLastSelectedMemberId(target.id);

    notifyListeners();
    return true;
  }

  /// Section 76: Generates member-scoped cache key to prevent data leakage between members
  String scopedCacheKey(String prefix, [String? memberId]) {
    final id = memberId ?? selectedMemberId ?? 'unselected';
    return '$prefix:$id';
  }

  /// Clears active context (e.g. on user logout)
  void clearContext() {
    _members = [];
    _selectedMember = null;
    _state = MemberContextState.noMemberSelected;
    _errorMessage = null;
    _switchSequence = 0;
    notifyListeners();
  }
}
