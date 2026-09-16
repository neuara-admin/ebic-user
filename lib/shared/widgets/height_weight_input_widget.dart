import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'bmi_health_widget.dart';

/// Clean, spacious, and intuitive dual-unit input widget for Height (cm or ft/in)
/// and Weight (kg or lbs), complete with live conversions and real-time BMI gauge.
class HeightWeightInputWidget extends StatefulWidget {
  final double? initialHeightCm;
  final double? initialWeightKg;
  final ValueChanged<double?> onHeightChanged;
  final ValueChanged<double?> onWeightChanged;
  final bool isRequired;

  const HeightWeightInputWidget({
    super.key,
    this.initialHeightCm,
    this.initialWeightKg,
    required this.onHeightChanged,
    required this.onWeightChanged,
    this.isRequired = true,
  });

  static const double minHeightCm = 40.0;
  static const double maxHeightCm = 260.0;
  static const double minWeightKg = 10.0;
  static const double maxWeightKg = 350.0;
  static const double minWeightLbs = 22.0;
  static const double maxWeightLbs = 770.0;

  @override
  State<HeightWeightInputWidget> createState() => _HeightWeightInputWidgetState();
}

class _HeightWeightInputWidgetState extends State<HeightWeightInputWidget> {
  // Height state
  bool _heightInFeet = false; // false = cm, true = ft/in
  late TextEditingController _heightCmCtrl;
  late TextEditingController _feetCtrl;
  late TextEditingController _inchesCtrl;

  // Weight state
  bool _weightInLbs = false; // false = kg, true = lbs
  late TextEditingController _weightKgCtrl;
  late TextEditingController _weightLbsCtrl;

  double? _currentHeightCm;
  double? _currentWeightKg;

  @override
  void initState() {
    super.initState();

    // Default to 175 cm (5'9") and 68.0 kg if initially null
    _currentHeightCm = widget.initialHeightCm ?? 175.0;
    _currentWeightKg = widget.initialWeightKg ?? 68.0;

    final ftIn = BmiHealthWidget.cmToFeetInches(_currentHeightCm!);
    _heightCmCtrl = TextEditingController(text: _currentHeightCm!.round().toString());
    _feetCtrl = TextEditingController(text: ftIn.feet.toString());
    _inchesCtrl = TextEditingController(text: ftIn.inches.toString());

    _weightKgCtrl = TextEditingController(text: _currentWeightKg!.toStringAsFixed(1));
    _weightLbsCtrl = TextEditingController(
      text: BmiHealthWidget.kgToLbs(_currentWeightKg!).toStringAsFixed(1),
    );

    // Notify initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onHeightChanged(_currentHeightCm);
      widget.onWeightChanged(_currentWeightKg);
    });
  }

  @override
  void dispose() {
    _heightCmCtrl.dispose();
    _feetCtrl.dispose();
    _inchesCtrl.dispose();
    _weightKgCtrl.dispose();
    _weightLbsCtrl.dispose();
    super.dispose();
  }

  void _onCmChanged(String val) {
    final cm = double.tryParse(val.trim());
    if (cm != null && cm > 0) {
      final ftIn = BmiHealthWidget.cmToFeetInches(cm);
      _feetCtrl.text = ftIn.feet.toString();
      _inchesCtrl.text = ftIn.inches.toString();
      setState(() => _currentHeightCm = cm);
      widget.onHeightChanged(cm);
    } else {
      setState(() => _currentHeightCm = null);
      widget.onHeightChanged(null);
    }
  }

  void _onFeetInchesChanged() {
    final feet = int.tryParse(_feetCtrl.text.trim()) ?? 0;
    final inches = int.tryParse(_inchesCtrl.text.trim()) ?? 0;
    if (feet > 0 || inches > 0) {
      final cm = BmiHealthWidget.feetInchesToCm(feet, inches);
      _heightCmCtrl.text = cm.round().toString();
      setState(() => _currentHeightCm = cm);
      widget.onHeightChanged(cm);
    } else {
      setState(() => _currentHeightCm = null);
      widget.onHeightChanged(null);
    }
  }

  void _onKgChanged(String val) {
    final kg = double.tryParse(val.trim());
    if (kg != null && kg > 0) {
      final lbs = BmiHealthWidget.kgToLbs(kg);
      _weightLbsCtrl.text = lbs.toStringAsFixed(1);
      setState(() => _currentWeightKg = kg);
      widget.onWeightChanged(kg);
    } else {
      setState(() => _currentWeightKg = null);
      widget.onWeightChanged(null);
    }
  }

  void _onLbsChanged(String val) {
    final lbs = double.tryParse(val.trim());
    if (lbs != null && lbs > 0) {
      final kg = BmiHealthWidget.lbsToKg(lbs);
      _weightKgCtrl.text = kg.toStringAsFixed(1);
      setState(() => _currentWeightKg = kg);
      widget.onWeightChanged(kg);
    } else {
      setState(() => _currentWeightKg = null);
      widget.onWeightChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. HEIGHT SECTION ──────────────────────────────────────────────
        _buildHeightSection(),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: AppColors.slate200),
        ),

        // ── 2. WEIGHT SECTION ──────────────────────────────────────────────
        _buildWeightSection(),

        const SizedBox(height: 18),

        // ── 3. LIVE BMI PREVIEW GAUGE ──────────────────────────────────────
        BmiHealthWidget(
          heightCm: _currentHeightCm,
          weightKg: _currentWeightKg,
        ),
      ],
    );
  }

  Widget _buildHeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Height Header with contextual unit selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.height_rounded, color: AppColors.primaryDark, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRequired ? 'Height *' : 'Height',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      _heightInFeet ? 'Range: 1\'4" – 8\'6"' : 'Range: 40 – 260 cm',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ],
            ),
            _buildSegmentedSwitch(
              leftLabel: 'cm',
              rightLabel: 'ft / in',
              isRightSelected: _heightInFeet,
              onChanged: (inFeet) => setState(() => _heightInFeet = inFeet),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Height Inputs
        if (_heightInFeet) ...[
          // Side-by-side Feet and Inches with comfortable width
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _feetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Feet',
                    hintText: '5',
                    suffixText: 'ft',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _onFeetInchesChanged(),
                  validator: (val) {
                    final f = int.tryParse(val?.trim() ?? '');
                    final inc = int.tryParse(_inchesCtrl.text.trim()) ?? 0;
                    if (f == null) return 'Required';
                    if (f < 1 || (f == 1 && inc < 4)) return 'Min 1\'4"';
                    if (f > 8 || (f == 8 && inc > 6)) return 'Max 8\'6"';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _inchesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Inches',
                    hintText: '9',
                    suffixText: 'in',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _onFeetInchesChanged(),
                  validator: (val) {
                    final inc = int.tryParse(val?.trim() ?? '');
                    final f = int.tryParse(_feetCtrl.text.trim()) ?? 0;
                    if (inc == null || inc < 0 || inc > 11) return '0–11 in';
                    if (f == 8 && inc > 6) return 'Max 6 in';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildLiveEquivalentPill(
            text: _currentHeightCm != null
                ? 'Equivalent to ≈ ${_currentHeightCm!.round()} cm'
                : 'e.g. 5 ft 9 in (≈ 175 cm)',
            icon: Icons.sync_rounded,
          ),
        ] else ...[
          // Metric cm Input
          TextFormField(
            controller: _heightCmCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Height in Centimeters',
              hintText: '175',
              prefixIcon: const Icon(Icons.straighten_rounded, size: 20, color: AppColors.slate500),
              suffixText: 'cm',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onCmChanged,
            validator: (val) {
              final h = double.tryParse(val?.trim() ?? '');
              if (h == null) return 'Please enter height';
              if (h < HeightWeightInputWidget.minHeightCm) return 'Minimum height is 40 cm';
              if (h > HeightWeightInputWidget.maxHeightCm) return 'Maximum height is 260 cm';
              return null;
            },
          ),
          const SizedBox(height: 6),
          _buildLiveEquivalentPill(
            text: _currentHeightCm != null
                ? 'Equivalent to ≈ ${BmiHealthWidget.cmToFeetInches(_currentHeightCm!).feet} ft ${BmiHealthWidget.cmToFeetInches(_currentHeightCm!).inches} in'
                : 'e.g. 175 cm (≈ 5 ft 9 in)',
            icon: Icons.sync_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weight Header with contextual unit selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.scale_rounded, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRequired ? 'Weight *' : 'Weight',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      _weightInLbs ? 'Range: 22 – 770 lbs' : 'Range: 10 – 350 kg',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ],
            ),
            _buildSegmentedSwitch(
              leftLabel: 'kg',
              rightLabel: 'lbs',
              isRightSelected: _weightInLbs,
              onChanged: (inLbs) => setState(() => _weightInLbs = inLbs),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weight Input
        if (_weightInLbs) ...[
          TextFormField(
            controller: _weightLbsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight in Pounds',
              hintText: '150.0',
              prefixIcon: const Icon(Icons.fitness_center_rounded, size: 20, color: AppColors.slate500),
              suffixText: 'lbs',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onLbsChanged,
            validator: (val) {
              final lbs = double.tryParse(val?.trim() ?? '');
              if (lbs == null) return 'Please enter weight';
              if (lbs < HeightWeightInputWidget.minWeightLbs) return 'Minimum weight is 22 lbs';
              if (lbs > HeightWeightInputWidget.maxWeightLbs) return 'Maximum weight is 770 lbs';
              return null;
            },
          ),
          const SizedBox(height: 6),
          _buildLiveEquivalentPill(
            text: _currentWeightKg != null
                ? 'Equivalent to ≈ ${_currentWeightKg!.toStringAsFixed(1)} kg'
                : 'e.g. 150 lbs (≈ 68.0 kg)',
            icon: Icons.sync_rounded,
          ),
        ] else ...[
          TextFormField(
            controller: _weightKgCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight in Kilograms',
              hintText: '68.0',
              prefixIcon: const Icon(Icons.monitor_weight_outlined, size: 20, color: AppColors.slate500),
              suffixText: 'kg',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onKgChanged,
            validator: (val) {
              final kg = double.tryParse(val?.trim() ?? '');
              if (kg == null) return 'Please enter weight';
              if (kg < HeightWeightInputWidget.minWeightKg) return 'Minimum weight is 10 kg';
              if (kg > HeightWeightInputWidget.maxWeightKg) return 'Maximum weight is 350 kg';
              return null;
            },
          ),
          const SizedBox(height: 6),
          _buildLiveEquivalentPill(
            text: _currentWeightKg != null
                ? 'Equivalent to ≈ ${BmiHealthWidget.kgToLbs(_currentWeightKg!).round()} lbs'
                : 'e.g. 68.0 kg (≈ 150 lbs)',
            icon: Icons.sync_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildSegmentedSwitch({
    required String leftLabel,
    required String rightLabel,
    required bool isRightSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentTab(
            label: leftLabel,
            isSelected: !isRightSelected,
            onTap: () => onChanged(false),
          ),
          _buildSegmentTab(
            label: rightLabel,
            isSelected: isRightSelected,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.slate900 : AppColors.slate500,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveEquivalentPill({
    required String text,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.slate400),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.slate600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
