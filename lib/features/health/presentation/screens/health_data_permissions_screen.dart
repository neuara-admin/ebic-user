import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_permission_model.dart';

class HealthDataPermissionsScreen extends StatefulWidget {
  final String memberId;

  const HealthDataPermissionsScreen({super.key, required this.memberId});

  @override
  State<HealthDataPermissionsScreen> createState() => _HealthDataPermissionsScreenState();
}

class _HealthDataPermissionsScreenState extends State<HealthDataPermissionsScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<HealthPermissionModel> _permissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataSource.getPermissions(widget.memberId);
      if (mounted) {
        setState(() {
          _permissions = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePermission(HealthPermissionModel item, bool enabled) async {
    final newStatus = enabled ? 'GRANTED' : 'REVOKED';

    // Optimistic update
    setState(() {
      final idx = _permissions.indexWhere((p) => p.id == item.id);
      if (idx != -1) {
        _permissions[idx] = HealthPermissionModel(
          id: item.id,
          householdMemberId: item.householdMemberId,
          dataType: item.dataType,
          provider: item.provider,
          purpose: item.purpose,
          status: newStatus,
        );
      }
    });

    try {
      await _dataSource.updatePermission(item.dataType, {
        'memberId': widget.memberId,
        'dataType': item.dataType,
        'provider': item.provider,
        'status': newStatus,
      });
    } catch (e) {
      _loadPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Data & Privacy'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transparency Header (Section 69)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Who Can Access My Health Data?',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAccessRule(
                          'Dietitian',
                          'Authorized for clinical nutrition consultation & diet plan authoring.',
                          Icons.medical_services_outlined,
                          AppColors.purple500,
                        ),
                        const SizedBox(height: 10),
                        _buildAccessRule(
                          'Chef',
                          'Limited exclusively to allergies & dietary restrictions for cooking safety.',
                          Icons.restaurant_outlined,
                          AppColors.accent,
                        ),
                        const SizedBox(height: 10),
                        _buildAccessRule(
                          'EBIC System',
                          'Used strictly to process scheduled orders, reminders, and delivery routing.',
                          Icons.security_rounded,
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Granular Data Permissions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You retain full control over each health category. Revoking a permission limits dietitian telemetry.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 12),

                  ..._permissions.map((perm) {
                    final isGranted = perm.isGranted;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isGranted ? AppColors.slate200 : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      perm.dataType,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isGranted ? AppColors.slate900 : AppColors.slate600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isGranted ? AppColors.primarySubtle : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        perm.provider,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isGranted ? AppColors.primaryDark : AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  perm.purpose,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isGranted,
                            onChanged: (val) => _togglePermission(perm, val),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildAccessRule(String role, String desc, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: AppColors.slate600, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
