import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';

class HealthMetricEntryScreen extends StatefulWidget {
  final String memberId;
  final String initialMetricType;
  final String initialUnit;

  const HealthMetricEntryScreen({
    super.key,
    required this.memberId,
    this.initialMetricType = 'WEIGHT',
    this.initialUnit = 'kg',
  });

  @override
  State<HealthMetricEntryScreen> createState() => _HealthMetricEntryScreenState();
}

class _HealthMetricEntryScreenState extends State<HealthMetricEntryScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  late String _metricType;
  late String _unit;
  final TextEditingController _valueCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  DateTime _recordedDate = DateTime.now();
  TimeOfDay _recordedTime = TimeOfDay.now();
  bool _isSaving = false;

  final List<Map<String, String>> _metrics = [
    {'type': 'WEIGHT', 'label': 'Weight', 'unit': 'kg'},
    {'type': 'HEIGHT', 'label': 'Height', 'unit': 'cm'},
    {'type': 'WATER', 'label': 'Water Intake', 'unit': 'ml'},
    {'type': 'STEPS', 'label': 'Daily Steps', 'unit': 'steps'},
    {'type': 'SLEEP_HOURS', 'label': 'Sleep Duration', 'unit': 'hours'},
    {'type': 'CALORIES', 'label': 'Calories Consumed', 'unit': 'kcal'},
    {'type': 'PROTEIN', 'label': 'Protein Intake', 'unit': 'g'},
  ];

  @override
  void initState() {
    super.initState();
    _metricType = widget.initialMetricType;
    _unit = widget.initialUnit;
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _recordedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _recordedTime,
    );
    if (picked != null) setState(() => _recordedTime = picked);
  }

  Future<void> _saveMetric() async {
    final val = double.tryParse(_valueCtrl.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive value.')),
      );
      return;
    }

    final combinedDateTime = DateTime(
      _recordedDate.year,
      _recordedDate.month,
      _recordedDate.day,
      _recordedTime.hour,
      _recordedTime.minute,
    );

    setState(() => _isSaving = true);
    try {
      await _dataSource.addMetric({
        'memberId': widget.memberId,
        'metricType': _metricType,
        'value': val,
        'unit': _unit,
        'recordedAt': combinedDateTime.toIso8601String(),
        'source': 'MANUAL',
        'notes': _notesCtrl.text.trim(),
        'idempotencyKey': 'metric_${DateTime.now().millisecondsSinceEpoch}',
      });

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metric entry saved successfully.'),
            backgroundColor: AppColors.emerald600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save metric: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : AppColors.slate200;
    final inputBg = isDark ? AppColors.slate800 : AppColors.slate50;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    final dateStr = DateFormat('dd MMM yyyy').format(_recordedDate);
    final timeStr = _recordedTime.format(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text('Add Measurement', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveMetric,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metric Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _metricType,
                dropdownColor: isDark ? AppColors.slate800 : Colors.white,
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Metric Type',
                  labelStyle: TextStyle(color: textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  filled: true,
                  fillColor: inputBg,
                ),
                items: _metrics
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['type'],
                        child: Text('${m['label']} (${m['unit']})', style: TextStyle(color: textPrimary)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _metricType = val;
                      _unit = _metrics.firstWhere((e) => e['type'] == val)['unit']!;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Recorded Value',
                  labelStyle: TextStyle(color: textSecondary),
                  suffixText: _unit,
                  suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  filled: true,
                  fillColor: inputBg,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          labelStyle: TextStyle(color: textSecondary),
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          filled: true,
                          fillColor: inputBg,
                        ),
                        child: Text(dateStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time',
                          labelStyle: TextStyle(color: textSecondary),
                          prefixIcon: Icon(Icons.access_time, size: 18, color: textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          filled: true,
                          fillColor: inputBg,
                        ),
                        child: Text(timeStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'e.g. Measured before breakfast',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  filled: true,
                  fillColor: inputBg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
