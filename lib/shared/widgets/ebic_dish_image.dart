import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

/// Standard culinary image widget for dishes across EBIC with robust URL resolution,
/// network error handling, smooth shimmer/loading states, and FSSAI-style dietary badges.
class EBICDishImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final bool? isVegetarian;
  final bool showVegIndicator;
  final BoxFit fit;
  final IconData? fallbackIcon;

  const EBICDishImage({
    super.key,
    required this.imageUrl,
    this.width = 86,
    this.height = 86,
    this.borderRadius = 14,
    this.isVegetarian,
    this.showVegIndicator = false,
    this.fit = BoxFit.cover,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedUrl = AppConfig.resolveMediaUrl(imageUrl);
    final hasValidUrl = resolvedUrl != null && resolvedUrl.trim().isNotEmpty;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
                width: 0.8,
              ),
            ),
            child: hasValidUrl
                ? Image.network(
                    resolvedUrl,
                    width: width,
                    height: height,
                    fit: fit,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _buildLoading(isDark);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallback(isDark);
                    },
                  )
                : _buildFallback(isDark),
          ),
        ),

        // Veg / Non-Veg Indicator Badge
        if (showVegIndicator && isVegetarian != null)
          Positioned(
            top: 6,
            left: 6,
            child: _buildVegIndicator(isVegetarian!),
          ),
      ],
    );
  }

  Widget _buildLoading(bool isDark) {
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Center(
        child: SizedBox(
          width: width * 0.28,
          height: width * 0.28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppColors.slate600 : AppColors.slate400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    final isVeg = isVegetarian ?? true;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVeg
              ? (isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)])
              : (isDark
                  ? [const Color(0xFF78350F), const Color(0xFF451A03)]
                  : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon ??
              (isVeg ? Icons.eco_rounded : Icons.restaurant_rounded),
          color: isVeg ? AppColors.primary : const Color(0xFFD97706),
          size: width * 0.42,
        ),
      ),
    );
  }

  Widget _buildVegIndicator(bool isVeg) {
    final color = isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(
            color: color,
            shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isVeg ? null : BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }
}
