import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ebic_card.dart';

/// A modern, clinical-grade multi-line notes input card with quick-suggestion pills
class ClinicalNotesInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String subtitle;
  final String hintText;

  const ClinicalNotesInputWidget({
    super.key,
    required this.controller,
    this.title = 'Clinical Notes & Dietitian Instructions',
    this.subtitle = 'Any symptoms, medical guidelines, recovery precautions, or food notes for your clinical dietitian.',
    this.hintText = 'e.g. Needs low-sodium meals, mild spices only, recovering from surgery...',
  });

  static const List<String> _quickSuggestions = [
    'Low sodium',
    'Mild spice only',
    'No onion / garlic',
    'Less oil',
    'Soft foods',
    'Post-surgery recovery',
  ];

  void _addSuggestion(String text) {
    final current = controller.text.trim();
    if (current.isEmpty) {
      controller.text = text;
    } else if (!current.toLowerCase().contains(text.toLowerCase())) {
      controller.text = '$current, $text';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.slate500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Multi-line Text Area
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 13, color: AppColors.slate800),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Suggestion Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickSuggestions.map((tag) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _addSuggestion(tag),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slate200, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
