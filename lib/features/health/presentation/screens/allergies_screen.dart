import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_allergy_model.dart';
import '../widgets/provenance_badge.dart';

class AllergiesScreen extends StatefulWidget {
  final String memberId;

  const AllergiesScreen({super.key, required this.memberId});

  @override
  State<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends State<AllergiesScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<HealthAllergyModel> _allergies = [];
  List<dynamic> _masterAllergens = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allergies = await _dataSource.getAllergies(widget.memberId);
      final master = await _dataSource.getDietaryPreferencesMaster();
      if (mounted) {
        setState(() {
          _allergies = allergies;
          _masterAllergens = master['allergens'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddAllergyDialog() async {
    String? selectedAllergenId;
    String selectedSeverity = 'UNKNOWN';
    final notesCtrl = TextEditingController();

    // Filter out already added allergens
    final recordedIds = Set.from(_allergies.map((a) => a.allergenId));
    final available = _masterAllergens.where((a) => !recordedIds.contains(a['id'])).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All available catalogue allergens are already added.')),
      );
      return;
    }

    selectedAllergenId = available.first['id'].toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Allergy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Reporting an allergy establishes a clinical safety constraint. EBIC chefs and dietitian algorithms block dishes containing this ingredient.',
                style: TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedAllergenId,
                decoration: InputDecoration(
                  labelText: 'Select Allergen',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
                ),
                items: available
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(a['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedAllergenId = val);
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: InputDecoration(
                  labelText: 'Severity Level',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
                ),
                items: const [
                  DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown / Mild Sensitivity')),
                  DropdownMenuItem(value: 'MILD', child: Text('Mild (Discomfort / Rash)')),
                  DropdownMenuItem(value: 'MODERATE', child: Text('Moderate (Digestive / Swelling)')),
                  DropdownMenuItem(value: 'SEVERE', child: Text('Severe (Anaphylaxis / Emergency)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedSeverity = val);
                },
              ),
              const SizedBox(height: 14),

              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Specific Notes / Triggers (Optional)',
                  hintText: 'e.g. Even trace amounts cause symptoms',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedAllergenId == null) return;
                    Navigator.pop(ctx);
                    await _dataSource.addAllergy({
                      'memberId': widget.memberId,
                      'allergenId': selectedAllergenId,
                      'severity': selectedSeverity,
                      'source': 'CUSTOMER_REPORTED',
                      'notes': notesCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Allergy Safety Constraint', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAllergy(HealthAllergyModel allergy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Allergy?'),
        content: Text(
          'Are you sure you want to remove ${allergy.name}? Removing this removes the automated safety block on dishes containing ${allergy.name}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dataSource.deleteAllergy(widget.memberId, allergy.allergenId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Allergies & Food Safety'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAllergyDialog,
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.shield_rounded, color: Colors.white),
        label: const Text('Add Allergy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Safety Banner (Section 21)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.danger, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Safety Rule (Section 21)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reported allergies are strictly enforced across meal planning and chef booking. Dishes with matching ingredients are hard-blocked by backend safety rules.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allergies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.emerald500),
                            const SizedBox(height: 12),
                            const Text(
                              'No Allergies Reported',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap below if this household member has any food allergies.',
                              style: TextStyle(fontSize: 13, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _allergies.length,
                        itemBuilder: (ctx, index) {
                          final allergy = _allergies[index];
                          return _buildAllergyCard(allergy);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyCard(HealthAllergyModel allergy) {
    Color severityColor;
    switch (allergy.severity) {
      case 'SEVERE':
        severityColor = AppColors.danger;
        break;
      case 'MODERATE':
        severityColor = AppColors.amber700;
        break;
      case 'MILD':
        severityColor = AppColors.secondary;
        break;
      default:
        severityColor = AppColors.slate600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block_rounded, color: AppColors.danger, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allergy.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            allergy.severity,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: severityColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ProvenanceBadge(source: allergy.source, isCompact: true),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.slate400),
                onPressed: () => _deleteAllergy(allergy),
              ),
            ],
          ),
          if (allergy.notes != null && allergy.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                allergy.notes!,
                style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
