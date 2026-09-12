import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebic_user/core/context/member_context.dart';
import 'package:ebic_user/core/storage/local_preferences.dart';
import 'package:ebic_user/shared/models/household_member_model.dart';
import 'package:ebic_user/shared/models/address_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 3 — Unit Tests: MemberContext (Sections 28, 33–39, 74–76)', () {
    late MemberContext context;

    final memberSelf = HouseholdMemberModel(
      id: 'mem-self-1',
      name: 'Rohan Sharma',
      relationship: 'SELF',
      isSelf: true,
      isCoveredByHealthPass: true,
      dateOfBirth: '1992-05-15',
    );

    final memberSpouse = HouseholdMemberModel(
      id: 'mem-spouse-2',
      name: 'Priya Sharma',
      relationship: 'SPOUSE',
      isSelf: false,
      isCoveredByHealthPass: true,
      dateOfBirth: '1995-08-20',
    );

    final memberChild = HouseholdMemberModel(
      id: 'mem-child-3',
      name: 'Aarav Sharma',
      relationship: 'CHILD',
      isSelf: false,
      isCoveredByHealthPass: false,
      dateOfBirth: '2020-03-10',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      context = MemberContext();
      context.clearContext();
    });

    test('MemberContext automatically selects isSelf member as default', () {
      context.setMembersForTesting([memberChild, memberSelf, memberSpouse]);

      expect(context.selectedMember, isNotNull);
      expect(context.selectedMemberId, equals('mem-self-1'));
      expect(context.selectedMember!.name, equals('Rohan Sharma'));
      expect(context.state, equals(MemberContextState.memberSelected));
    });

    test('MemberContext switches active member and updates state', () async {
      context.setMembersForTesting([memberSelf, memberSpouse]);
      expect(context.selectedMemberId, equals('mem-self-1'));

      final success = await context.selectMember('mem-spouse-2');
      expect(success, isTrue);
      expect(context.selectedMemberId, equals('mem-spouse-2'));
      expect(context.selectedMember!.name, equals('Priya Sharma'));

      // Check persistence in LocalPreferences (Section 39)
      final prefs = await LocalPreferences.getInstance();
      expect(prefs.lastSelectedMemberId, equals('mem-spouse-2'));
    });

    test('MemberContext rejects switching to non-existent member', () async {
      context.setMembersForTesting([memberSelf]);

      final success = await context.selectMember('unknown-id');
      expect(success, isFalse);
      expect(context.state, equals(MemberContextState.memberSelectionFailed));
    });

    test('Section 76: Scoped cache key strictly includes memberId to avoid data leak', () {
      context.setMembersForTesting([memberSelf, memberSpouse]);
      context.selectMember('mem-spouse-2');

      final dietPlanKey = context.scopedCacheKey('diet_plan');
      expect(dietPlanKey, equals('diet_plan:mem-spouse-2'));

      final healthKey = context.scopedCacheKey('health_profile', 'mem-self-1');
      expect(healthKey, equals('health_profile:mem-self-1'));
    });

    test('Section 20 & 26: Member age is computed accurately from date of birth', () {
      expect(memberSelf.age, greaterThanOrEqualTo(30));
      expect(memberChild.age, lessThanOrEqualTo(10));
      expect(memberSelf.initials, equals('RS'));
      expect(memberSpouse.displayRelationship, equals('Spouse / Partner'));
    });
  });

  group('Module 3 — Unit Tests: Address Model & Serviceability (Sections 29–31, 51)', () {
    test('AddressModel correctly parses authoritative backend serviceability statuses', () {
      final addrServiceable = AddressModel.fromJson({
        'id': 'addr-1',
        'label': 'Home',
        'line1': '101 Palm Meadows',
        'lat': 12.971,
        'lng': 77.594,
        'hubId': 'hub-hsr',
        'hub': {'id': 'hub-hsr', 'name': 'HSR Hub'},
        'status': 'SERVICEABLE',
        'isDefault': true,
      });

      expect(addrServiceable.isServiceable, isTrue);
      expect(addrServiceable.serviceabilityBadgeText, equals('SERVICEABLE'));
      expect(addrServiceable.isDefault, isTrue);

      final addrOutside = AddressModel.fromJson({
        'id': 'addr-2',
        'label': 'Farmhouse',
        'line1': 'Survey 42, Outskirts',
        'lat': 13.5,
        'lng': 77.1,
        'hubId': null,
        'status': 'OUTSIDE_SERVICE_AREA',
        'isDefault': false,
      });

      expect(addrOutside.isServiceable, isFalse);
      expect(addrOutside.serviceabilityBadgeText, equals('UNSERVICEABLE'));
    });

    test('ServiceabilityResult parses backend response', () {
      final res = ServiceabilityResult.fromJson({
        'serviceable': true,
        'hubId': 'hub-1',
        'hubName': 'Indiranagar Hub',
        'status': 'SERVICEABLE',
        'message': 'Chef service is available at this address.',
      });

      expect(res.isServiceable, isTrue);
      expect(res.hubName, equals('Indiranagar Hub'));
      expect(res.message, contains('available'));
    });
  });
}
