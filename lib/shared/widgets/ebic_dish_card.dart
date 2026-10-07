import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

/// Pre-styled bespoke menu/catalogue dish card with cook time, macros, and price.
/// Follows the flutter-bespoke-ui design principles:
/// - Tactile spring-scale micro-interaction (scale down to 0.982) with haptics
/// - 1px hairline border + diffuse ambient glow
/// - Squircle image container with hairline frame
/// - Stat-first badges for cook time & calories
class EBICDishCard extends StatefulWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final int? cookTimeMinutes;
  final int? calories;
  final String? price;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool showAddButton;

  const EBICDishCard({
    super.key,
    required this.name,
    this.description,
    this.imageUrl,
    this.cookTimeMinutes,
    this.calories,
    this.price,
    this.isSelected = false,
    this.onTap,
    this.onAdd,
    this.showAddButton = true,
  });

  @override
  State<EBICDishCard> createState() => _EBICDishCardState();
}

class _EBICDishCardState extends State<EBICDishCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final borderColor = widget.isSelected
        ? AppColors.primary
        : (isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFF0F172A).withOpacity(0.06));

    return AnimatedScale(
      scale: (_isPressed && widget.onTap != null) ? 0.982 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: widget.isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(isDark ? 0.28 : 0.04),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(isDark ? 0.10 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            onHighlightChanged: widget.onTap != null
                ? (highlighted) {
                    setState(() => _isPressed = highlighted);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  // Image or Dish placeholder icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFF0F172A).withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                          ? Image.network(
                              AppConfig.resolveMediaUrl(widget.imageUrl) ?? widget.imageUrl!,
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.description != null && widget.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (widget.cookTimeMinutes != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.slate500),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.cookTimeMinutes}m',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.calories != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7).withOpacity(isDark ? 0.2 : 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFD97706)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.calories} kcal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (widget.price != null)
                              Text(
                                widget.price!,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.showAddButton && widget.onAdd != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        widget.isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        color: widget.isSelected ? AppColors.primary : AppColors.slate400,
                        size: 26,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onAdd!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 78,
      height: 78,
      color: AppColors.primarySubtle,
      child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 28),
    );
  }
}
