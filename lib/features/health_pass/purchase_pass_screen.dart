import 'package:flutter/material.dart';
import '../../shared/models/health_pass_model.dart';
import 'plan_configure_screen.dart';

/// Backward-compatible wrapper delegating to HealthPassConfigureScreen (Sections 36 & 37)
class PurchasePassScreen extends StatelessWidget {
  final Map<String, dynamic> purchaseData;

  const PurchasePassScreen({super.key, required this.purchaseData});

  @override
  Widget build(BuildContext context) {
    final plan = purchaseData['plan'] as HealthPassPlanModel?;
    final planCode = plan?.code ?? purchaseData['planCode']?.toString() ?? 'CARE_V1';

    return HealthPassConfigureScreen(
      arguments: {
        'planCode': planCode,
        'planName': plan?.name ?? 'EBIC Care',
      },
    );
  }
}
