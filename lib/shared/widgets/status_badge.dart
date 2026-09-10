import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  StatusBadge({
    super.key,
    String? status,
    String? label,
    Color? color,
    this.icon,
  })  : label = label ?? _formatStatus(status ?? 'ACTIVE'),
        color = color ?? _getStatusColor(status ?? 'ACTIVE');

  factory StatusBadge.success(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.success, icon: icon);

  factory StatusBadge.warning(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.warning, icon: icon);

  factory StatusBadge.danger(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.danger, icon: icon);

  factory StatusBadge.info(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.info, icon: icon);

  static String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  static Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'COMPLETED':
      case 'CONFIRMED':
      case 'READY':
      case 'DELIVERED':
      case 'OPEN':
        return AppColors.primary;
      case 'IN_PROGRESS':
      case 'COOKING':
      case 'PLATING':
      case 'CHEF_EN_ROUTE':
      case 'CHEF_ASSIGNED':
      case 'SCHEDULED':
        return AppColors.accent;
      case 'CANCELLED':
      case 'FAILED':
      case 'EXPIRED':
      case 'REJECTED':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
