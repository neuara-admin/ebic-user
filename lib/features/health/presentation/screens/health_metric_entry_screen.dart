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
    final dateStr = DateFormat('dd MMM yyyy').format(_recordedDate);
    final timeStr = _recordedTime.format(context);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Add Measurement'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate200)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metric Details (Section 32)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _metricType,
                decoration: InputDecoration(
                  labelText: 'Metric Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
                ),
                items: _metrics
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['type'],
                        child: Text('${m['label']} (${m['unit']})'),
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Recorded Value',
                  suffixText: _unit,
                  suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
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
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.slate50,
                        ),
                        child: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                          prefixIcon: const Icon(Icons.access_time, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.slate50,
                        ),
                        child: Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'e.g. Measured before breakfast',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.slate50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
