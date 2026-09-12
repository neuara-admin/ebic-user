import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

enum LoadingType { spinner, progress, skeleton }

/// Centralized loader supporting Spinner, Progress indicator, and Skeleton loaders.
/// Adheres to Section 6.2 (EBICLoader) and Section 23 (Loading Global State).
class LoadingView extends StatelessWidget {
  final String? message;
  final LoadingType type;
  final double? progress;
  final double? skeletonWidth;
  final double? skeletonHeight;
  final BorderRadius? skeletonRadius;

  const LoadingView({
    super.key,
    this.message,
    this.type = LoadingType.spinner,
    this.progress,
    this.skeletonWidth,
    this.skeletonHeight,
    this.skeletonRadius,
  });

  const LoadingView.spinner({
    super.key,
    this.message,
  })  : type = LoadingType.spinner,
        progress = null,
        skeletonWidth = null,
        skeletonHeight = null,
        skeletonRadius = null;

  const LoadingView.progress({
    super.key,
    required double this.progress,
    this.message,
  })  : type = LoadingType.progress,
        skeletonWidth = null,
        skeletonHeight = null,
        skeletonRadius = null;

  const LoadingView.skeleton({
    super.key,
    this.skeletonWidth = double.infinity,
    this.skeletonHeight = 16.0,
    this.skeletonRadius,
  })  : type = LoadingType.skeleton,
        message = null,
        progress = null;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoadingType.progress:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  color: AppColors.primary,
                  backgroundColor: AppColors.slate200,
                  borderRadius: DesignTokens.borderRadiusPill,
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                ],
              ],
            ),
          ),
        );

      case LoadingType.skeleton:
        return Container(
          width: skeletonWidth,
          height: skeletonHeight,
          decoration: BoxDecoration(
            color: AppColors.slate200,
            borderRadius: skeletonRadius ?? DesignTokens.borderRadiusSM,
          ),
        );

      case LoadingType.spinner:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// Typedef matching Section 6.2 specification naming.
typedef EBICLoader = LoadingView;
