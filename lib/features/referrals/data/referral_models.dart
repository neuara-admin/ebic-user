import 'package:intl/intl.dart';

class ReferralStatsModel {
  final int invited;
  final int qualified;
  final int rewarded;

  const ReferralStatsModel({
    required this.invited,
    required this.qualified,
    required this.rewarded,
  });

  factory ReferralStatsModel.fromJson(Map<String, dynamic> json) {
    return ReferralStatsModel(
      invited: (json['invited'] as num?)?.toInt() ?? 0,
      qualified: (json['qualified'] as num?)?.toInt() ?? 0,
      rewarded: (json['rewarded'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReferralCampaignModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String qualificationType;
  final double referrerRewardAmount;
  final double refereeRewardAmount;
  final String? terms;
  final DateTime? endAt;

  const ReferralCampaignModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.qualificationType,
    required this.referrerRewardAmount,
    required this.refereeRewardAmount,
    this.terms,
    this.endAt,
  });

  factory ReferralCampaignModel.fromJson(Map<String, dynamic> json) {
    final rewardConfig = json['rewardConfig'] as Map<String, dynamic>? ?? {};
    return ReferralCampaignModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'EBIC Friends & Family Referral',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      qualificationType: json['qualificationType']?.toString() ?? 'FIRST_SUCCESSFUL_HEALTH_PASS_PURCHASE',
      referrerRewardAmount: double.tryParse(rewardConfig['referrerAmount']?.toString() ?? '250') ?? 250.0,
      refereeRewardAmount: double.tryParse(rewardConfig['refereeAmount']?.toString() ?? '150') ?? 150.0,
      terms: json['terms']?.toString(),
      endAt: json['endAt'] != null ? DateTime.tryParse(json['endAt'].toString()) : null,
    );
  }

  String get humanReadableQualification {
    switch (qualificationType) {
      case 'FIRST_SUCCESSFUL_HEALTH_PASS_PURCHASE':
        return 'First successful Health Pass purchase';
      case 'FIRST_SUCCESSFUL_CHEF_BOOKING':
        return 'First successful Chef Booking';
      case 'FIRST_PAID_ORDER':
        return 'First paid meal or booking';
      case 'ORDER_VALUE_THRESHOLD':
        return 'Order value reaches required minimum';
      default:
        return 'First completed service';
    }
  }
}

class ReferralItemModel {
  final String id;
  final String friendName;
  final String status;
  final String? rewardStatus;
  final double? rewardAmount;
  final String? campaignName;
  final DateTime? registeredAt;
  final DateTime? qualifiedAt;
  final DateTime? createdAt;
  final List<ReferralTimelineEvent> timeline;

  const ReferralItemModel({
    required this.id,
    required this.friendName,
    required this.status,
    this.rewardStatus,
    this.rewardAmount,
    this.campaignName,
    this.registeredAt,
    this.qualifiedAt,
    this.createdAt,
    this.timeline = const [],
  });

  factory ReferralItemModel.fromJson(Map<String, dynamic> json) {
    String name = 'Friend';
    if (json['referredUser'] is Map) {
      final ru = json['referredUser'] as Map<String, dynamic>;
      name = ru['name']?.toString() ??
          (ru['phone'] != null ? 'User (${ru['phone'].toString().substring((ru['phone'].toString().length - 4).clamp(0, ru['phone'].toString().length))})' : 'Friend');
    } else if (json['friendName'] != null) {
      name = json['friendName'].toString();
    }

    final rewards = (json['rewards'] as List<dynamic>?) ?? [];
    String? rStatus;
    double? rAmt;
    if (rewards.isNotEmpty && rewards.first is Map) {
      final firstReward = rewards.first as Map<String, dynamic>;
      rStatus = firstReward['status']?.toString();
      rAmt = double.tryParse(firstReward['amount']?.toString() ?? '');
    }

    final eventsRaw = (json['events'] as List<dynamic>?) ?? [];
    final parsedEvents = eventsRaw
        .map((e) => e is Map<String, dynamic> ? ReferralTimelineEvent.fromJson(e) : null)
        .whereType<ReferralTimelineEvent>()
        .toList();

    return ReferralItemModel(
      id: json['id']?.toString() ?? '',
      friendName: name,
      status: json['status']?.toString() ?? 'PENDING',
      rewardStatus: rStatus ?? json['rewardStatus']?.toString(),
      rewardAmount: rAmt,
      campaignName: json['campaign']?['name']?.toString() ?? json['campaignName']?.toString(),
      registeredAt: json['registeredAt'] != null ? DateTime.tryParse(json['registeredAt'].toString()) : null,
      qualifiedAt: json['qualifiedAt'] != null ? DateTime.tryParse(json['qualifiedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      timeline: parsedEvents,
    );
  }

  String get joinedDateDisplay {
    final dt = registeredAt ?? createdAt;
    if (dt == null) return 'Pending join';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  String get humanStatus {
    switch (status.toUpperCase()) {
      case 'QUALIFIED':
        return 'Qualified';
      case 'REWARDED':
        return 'Rewarded';
      case 'REWARD_PENDING':
        return 'Reward Pending';
      case 'REGISTERED':
        return 'Registered';
      case 'ATTRIBUTED':
        return 'Link Opened';
      case 'ELIGIBLE':
        return 'Eligible';
      case 'EXPIRED':
        return 'Expired';
      case 'INVALID':
      case 'REJECTED':
      case 'FRAUD_REVIEW':
        return 'In Review';
      default:
        return 'Pending';
    }
  }

  String get humanRewardStatus {
    if (status.toUpperCase() == 'REWARDED' || rewardStatus?.toUpperCase() == 'ISSUED') {
      return 'Credited';
    }
    if (rewardStatus?.toUpperCase() == 'PENDING' || status.toUpperCase() == 'REWARD_PENDING') {
      return 'Processing';
    }
    if (status.toUpperCase() == 'QUALIFIED') {
      return 'Approved';
    }
    return 'Pending Action';
  }
}

class ReferralTimelineEvent {
  final String eventType;
  final String? source;
  final DateTime? occurredAt;

  const ReferralTimelineEvent({
    required this.eventType,
    this.source,
    this.occurredAt,
  });

  factory ReferralTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ReferralTimelineEvent(
      eventType: json['eventType']?.toString() ?? 'EVENT',
      source: json['source']?.toString(),
      occurredAt: json['occurredAt'] != null ? DateTime.tryParse(json['occurredAt'].toString()) : null,
    );
  }

  String get label {
    switch (eventType) {
      case 'LINK_CLICKED':
        return 'Referral Link Clicked';
      case 'APP_OPENED':
        return 'EBIC App Installed & Opened';
      case 'REGISTERED':
        return 'Account Created & Attributed';
      case 'FIRST_PURCHASE':
        return 'Qualifying Purchase Completed';
      case 'QUALIFIED':
        return 'Referral Rules Qualified';
      case 'REWARD_CREATED':
        return 'Reward Prepared';
      case 'REWARD_ISSUED':
        return 'Wallet Credit Issued';
      case 'REWARD_REVERSED':
        return 'Reward Reversed';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }
}

class ReferralDashboardModel {
  final String referralCode;
  final String shareUrl;
  final ReferralStatsModel stats;
  final ReferralCampaignModel? activeCampaign;
  final List<ReferralItemModel> recentReferrals;

  const ReferralDashboardModel({
    required this.referralCode,
    required this.shareUrl,
    required this.stats,
    this.activeCampaign,
    this.recentReferrals = const [],
  });

  factory ReferralDashboardModel.fromJson(Map<String, dynamic> json) {
    final statsObj = json['stats'] is Map<String, dynamic>
        ? ReferralStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
        : const ReferralStatsModel(invited: 0, qualified: 0, rewarded: 0);

    ReferralCampaignModel? camp;
    if (json['activeCampaign'] is Map<String, dynamic> && (json['activeCampaign'] as Map).isNotEmpty) {
      camp = ReferralCampaignModel.fromJson(json['activeCampaign'] as Map<String, dynamic>);
    }

    final recentRaw = (json['recentReferrals'] as List<dynamic>?) ?? [];
    final parsedRecent = recentRaw
        .map((e) => e is Map<String, dynamic> ? ReferralItemModel.fromJson(e) : null)
        .whereType<ReferralItemModel>()
        .toList();

    return ReferralDashboardModel(
      referralCode: json['referralCode']?.toString() ?? '',
      shareUrl: json['shareUrl']?.toString() ?? 'https://ebic.app/r/${json['referralCode'] ?? ''}',
      stats: statsObj,
      activeCampaign: camp,
      recentReferrals: parsedRecent,
    );
  }
}
