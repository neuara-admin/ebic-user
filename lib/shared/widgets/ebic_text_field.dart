import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Centralized Text Field for EBIC User App.
/// Part of the core component suite (Section 6.2).
class EBICTextField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool isPassword;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final bool showClearButton;
  final FocusNode? focusNode;

  const EBICTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.isPassword = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.showClearButton = false,
    this.focusNode,
  });

  @override
  State<EBICTextField> createState() => _EBICTextFieldState();
}

class _EBICTextFieldState extends State<EBICTextField> {
  late bool _obscureText;
  late TextEditingController _effectiveController;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? suffixWidget = widget.suffix;
    if (widget.isPassword) {
      suffixWidget = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.slate400,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      );
    } else if (widget.showClearButton && _effectiveController.text.isNotEmpty) {
      suffixWidget = IconButton(
        icon: const Icon(Icons.clear_rounded, color: AppColors.slate400, size: 18),
        onPressed: () {
          _effectiveController.clear();
          widget.onChanged?.call('');
          setState(() {});
        },
      );
    }

    return Semantics(
      label: widget.label ?? widget.hintText ?? 'Text input',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate200 : AppColors.slate800,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXS),
          ],
          TextFormField(
            controller: _effectiveController,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: _obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            validator: widget.validator,
            onChanged: (val) {
              widget.onChanged?.call(val);
              if (widget.showClearButton) setState(() {});
            },
            onFieldSubmitted: widget.onSubmitted,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: widget.errorText,
              prefixIcon: widget.prefix,
              suffixIcon: suffixWidget,
              filled: true,
              fillColor: isDark ? AppColors.slate800 : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMD,
                borderSide: BorderSide(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMD,
                borderSide: BorderSide(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMD,
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMD,
                borderSide: const BorderSide(
                  color: AppColors.danger,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
