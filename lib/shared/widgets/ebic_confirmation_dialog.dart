import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_dialog.dart';
import 'ebic_button.dart';
import 'ebic_text_button.dart';

/// Pre-styled confirmation dialog (Confirm / Cancel) for EBIC User App.
/// Part of the core component suite (Section 6.2).
class EBICConfirmationDialog {
  EBICConfirmationDialog._();

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await EBICDialog.show<bool>(
      context: context,
      icon: icon != null
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.danger : AppColors.primary).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.danger : AppColors.primary,
                size: 28,
              ),
            )
          : null,
      title: title,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.slate600,
          height: 1.5,
        ),
      ),
      actions: [
        EBICTextButton(
          label: cancelLabel,
          color: AppColors.slate500,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: EbicButton(
            label: confirmLabel,
            variant: isDestructive ? EbicButtonVariant.danger : EbicButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );

    return result ?? false;
  }
}
