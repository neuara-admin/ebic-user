/// Section 44 & 45 - Deletion Eligibility Result Entity
class AccountDeletionEligibility {
  final bool eligible;
  final List<String> blockingReasons;
  final int activeOrders;
  final int activePasses;
  final int pendingRefunds;

  const AccountDeletionEligibility({
    required this.eligible,
    required this.blockingReasons,
    this.activeOrders = 0,
    this.activePasses = 0,
    this.pendingRefunds = 0,
  });

  factory AccountDeletionEligibility.fromJson(Map<String, dynamic> json) {
    final reasons = (json['blockingReasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final activeTx = json['activeTransactions'] as Map<String, dynamic>?;

    return AccountDeletionEligibility(
      eligible: json['eligible'] as bool? ?? (reasons.isEmpty),
      blockingReasons: reasons,
      activeOrders: activeTx?['activeOrders'] as int? ?? 0,
      activePasses: activeTx?['activePasses'] as int? ?? 0,
      pendingRefunds: activeTx?['pendingRefunds'] as int? ?? 0,
    );
  }
}
