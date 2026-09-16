import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_goal_model.dart';

class HealthGoalsScreen extends StatefulWidget {
  final String memberId;

  const HealthGoalsScreen({super.key, required this.memberId});

  @override
  State<HealthGoalsScreen> createState() => _HealthGoalsScreenState();
}

class _HealthGoalsScreenState extends State<HealthGoalsScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<HealthGoalModel> _goals = [];
  bool _isLoading = true;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataSource.getGoals(widget.memberId);
      if (mounted) {
        setState(() {
          _goals = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddGoalDialog([HealthGoalModel? editGoal]) async {
    final titleCtrl = TextEditingController(text: editGoal?.title ?? '');
    final descCtrl = TextEditingController(text: editGoal?.description ?? '');
    final targetValueCtrl = TextEditingController(
      text: editGoal?.targetValue != null ? editGoal!.targetValue.toString() : '',
    );
    final targetUnitCtrl = TextEditingController(text: editGoal?.targetUnit ?? '');
    String selectedType = editGoal?.goalType ?? 'WEIGHT_MANAGEMENT';

    final goalTypes = [
      {'key': 'WEIGHT_MANAGEMENT', 'label': 'Weight Management'},
      {'key': 'IMPROVE_NUTRITION', 'label': 'Improve Overall Nutrition'},
      {'key': 'INCREASE_PROTEIN', 'label': 'Increase Protein Intake'},
      {'key': 'IMPROVE_HYDRATION', 'label': 'Improve Daily Hydration'},
      {'key': 'MEAL_CONSISTENCY', 'label': 'Improve Meal Consistency'},
      {'key': 'FITNESS_NUTRITION', 'label': 'Fitness & Performance'},
      {'key': 'OTHER', 'label': 'Custom Health Goal'},
    ];

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editGoal == null ? 'Define Health Goal' : 'Edit Health Goal',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customer goals inform your dietitian during consultation and are reviewed before meal plan assignment.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Goal Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.slate50,
                  ),
                  items: goalTypes
                      .map((t) => DropdownMenuItem(value: t['key'], child: Text(t['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedType = val;
                        if (titleCtrl.text.isEmpty) {
                          titleCtrl.text = goalTypes.firstWhere((e) => e['key'] == val)['label']!;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. Target weight 70 kg by November',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.slate50,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: targetValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Target Value',
                          hintText: '70',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.slate50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: targetUnitCtrl,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          hintText: 'kg',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.slate50,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes for Dietitian (Optional)',
                    hintText: 'Describe your routine or motivation...',
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
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final val = double.tryParse(targetValueCtrl.text.trim());
                      if (editGoal == null) {
                        await _dataSource.createGoal({
                          'memberId': widget.memberId,
                          'goalType': selectedType,
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'targetValue': val,
                          'targetUnit': targetUnitCtrl.text.trim(),
                        });
                      } else {
                        await _dataSource.updateGoal(editGoal.id, {
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'targetValue': val,
                          'targetUnit': targetUnitCtrl.text.trim(),
                        });
                      }
                      _loadGoals();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(editGoal == null ? 'Add Goal' : 'Save Goal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateGoalStatus(HealthGoalModel goal, String newStatus) async {
    await _dataSource.updateGoal(goal.id, {'status': newStatus});
    _loadGoals();
  }

  Future<void> _deleteGoal(HealthGoalModel goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to remove "${goal.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dataSource.deleteGoal(goal.id);
      _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGoals = _statusFilter == 'ALL'
        ? _goals
        : _goals.where((g) => g.status == _statusFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Goals'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Goals'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ACTIVE', 'Active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ACHIEVED', 'Achieved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PAUSED', 'Paused'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // Goals List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredGoals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_outlined, size: 48, color: AppColors.slate400),
                            const SizedBox(height: 12),
                            const Text(
                              'No goals in this section',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Define goals to guide your dietitian during planning.',
                              style: TextStyle(fontSize: 13, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredGoals.length,
                        itemBuilder: (ctx, index) {
                          final goal = filteredGoals[index];
                          return _buildGoalCard(goal);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) setState(() => _statusFilter = key);
      },
      selectedColor: AppColors.primarySubtle,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryDark : AppColors.slate600,
      ),
    );
  }

  Widget _buildGoalCard(HealthGoalModel goal) {
    Color statusColor;
    switch (goal.status) {
      case 'ACHIEVED':
        statusColor = AppColors.emerald600;
        break;
      case 'PAUSED':
        statusColor = AppColors.amber700;
        break;
      case 'CANCELLED':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  goal.status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.slate500),
                onSelected: (action) {
                  if (action == 'EDIT') _showAddGoalDialog(goal);
                  if (action == 'ACHIEVE') _updateGoalStatus(goal, 'ACHIEVED');
                  if (action == 'ACTIVE') _updateGoalStatus(goal, 'ACTIVE');
                  if (action == 'PAUSE') _updateGoalStatus(goal, 'PAUSED');
                  if (action == 'DELETE') _deleteGoal(goal);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'EDIT', child: Text('Edit Goal')),
                  if (goal.status != 'ACHIEVED')
                    const PopupMenuItem(value: 'ACHIEVE', child: Text('Mark as Achieved')),
                  if (goal.status != 'ACTIVE')
                    const PopupMenuItem(value: 'ACTIVE', child: Text('Mark as Active')),
                  if (goal.status != 'PAUSED')
                    const PopupMenuItem(value: 'PAUSE', child: Text('Pause Goal')),
                  const PopupMenuItem(
                    value: 'DELETE',
                    child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          if (goal.targetValue != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.track_changes_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Target: ${goal.targetValue} ${goal.targetUnit ?? ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
                ),
              ],
            ),
          ],
          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
