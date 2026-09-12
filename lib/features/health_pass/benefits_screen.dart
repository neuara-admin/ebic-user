import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Section 42: Health Pass Benefits & Media Screen
/// Authoritatively renders plan benefits, photos, and video guidance dynamically from the backend.
class HealthPassBenefitsScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassBenefitsScreen({super.key, required this.arguments});

  @override
  State<HealthPassBenefitsScreen> createState() => _HealthPassBenefitsScreenState();
}

class _HealthPassBenefitsScreenState extends State<HealthPassBenefitsScreen> {
  final HealthPassRepository _repository = HealthPassRepository();

  HealthPassPlanModel? _plan;
  bool _isLoading = true;
  String? _errorMessage;

  int _activeSlideIndex = 0;
  final PageController _slideController = PageController();

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initPlan();
  }

  Future<void> _initPlan() async {
    final passedPlan = widget.arguments['plan'];
    if (passedPlan is HealthPassPlanModel) {
      setState(() {
        _plan = passedPlan;
        _isLoading = false;
      });
      return;
    }

    final planCode = widget.arguments['planCode']?.toString() ?? 'CARE_V1';
    await _fetchPlan(planCode);
  }

  Future<void> _fetchPlan(String planCode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plan = await _repository.fetchPlanById(planCode);
      if (mounted) {
        setState(() {
          _plan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  IconData _getBenefitIcon(String type, String code) {
    switch (type.toUpperCase()) {
      case 'FREE_VISITS':
        return Icons.restaurant_menu_rounded;
      case 'CONSULTATION':
        return Icons.video_call_rounded;
      case 'DIET_PLAN':
        return Icons.description_outlined;
      case 'CHAT':
        return Icons.chat_outlined;
      default:
        if (code.contains('CHEF') || code.contains('VISIT')) {
          return Icons.restaurant_menu_rounded;
        }
        if (code.contains('CONSULT')) {
          return Icons.video_call_rounded;
        }
        if (code.contains('DIET')) {
          return Icons.description_outlined;
        }
        if (code.contains('CHAT')) {
          return Icons.chat_outlined;
        }
        return Icons.verified_outlined;
    }
  }

  String _formatTag(HealthPassBenefitModel b) {
    if (b.quantity != null && b.quantity! > 0) {
      return '${b.quantity} / ${b.frequency.toLowerCase()}';
    }
    if (b.allowanceScope == 'SHARED') {
      return 'SHARED POOL';
    }
    return b.allowanceScope.replaceAll('_', ' ');
  }

  void _showMediaPreview(String title, String url, bool isVideo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: isVideo
                  ? SizedBox(
                      height: 220,
                      child: _AutoPlayVideoWidget(
                        videoUrl: url,
                        autoPlay: true,
                        isMuted: false,
                        showControls: true,
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isVideo ? 'Authoritative Health Pass Orientation Video' : 'Health Pass Facility & Service Photo',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final planName = widget.arguments['planName']?.toString() ?? _plan?.displayName ?? 'Health Pass';

    final mediaSlides = _getMediaSlides();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('$planName Benefits'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        EbicButton(
                          label: 'Retry',
                          onPressed: () => _fetchPlan(widget.arguments['planCode']?.toString() ?? 'CARE_V1'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchPlan(_plan?.code ?? 'CARE_V1'),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Media Slider (Images & Videos) or Fallback Branded Hero Card
                        if (mediaSlides.isNotEmpty)
                          _buildMediaSlider(mediaSlides, isDark)
                        else
                          _buildNoMediaHeroCard(isDark),

                        // Authoritative Benefits Section
                        const Text(
                          'AUTHORITATIVE PLAN PRIVILEGES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_plan?.benefits.isEmpty ?? true)
                          const EbicCard(
                            child: Text(
                              'No benefits configured for this plan version yet.',
                              style: TextStyle(fontSize: 13, color: AppColors.slate500),
                            ),
                          )
                        else
                          ..._plan!.benefits.map((b) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildBenefitCard(b, isDark),
                              )),

                        const SizedBox(height: 16),

                        // Fair Use / Entitlement Policy Notice
                        EbicCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppColors.slate400),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Health Pass benefits reflect live configuration from EBIC health & nutrition catalog. Entitlements refresh every monthly cycle for all active covered members.',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Button
                        if (_plan != null)
                          EbicButton(
                            label: 'Configure & Subscribe to ${_plan!.displayName}',
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.healthPassConfigure,
                                arguments: {'planCode': _plan!.code, 'planName': _plan!.name},
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBenefitCard(HealthPassBenefitModel b, bool isDark) {
    final icon = _getBenefitIcon(b.benefitType, b.code);
    final tag = _formatTag(b);

    return EbicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryLight : AppColors.primary),
                      ),
                    ),
                  ],
                ),
                if (b.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    b.description,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MediaSlideItem> _getMediaSlides() {
    if (_plan == null) return [];
    final slides = <_MediaSlideItem>[];

    // Videos
    for (final vid in _plan!.videos) {
      if (vid.url.trim().isNotEmpty) {
        slides.add(_MediaSlideItem(isVideo: true, url: vid.url, title: vid.title));
      }
    }

    // Images
    for (final img in _plan!.images) {
      if (img.url.trim().isNotEmpty) {
        slides.add(_MediaSlideItem(isVideo: false, url: img.url, title: img.title));
      }
    }

    // Single cover image if not already included
    if (slides.where((s) => !s.isVideo).isEmpty &&
        _plan!.imageUrl != null &&
        _plan!.imageUrl!.trim().isNotEmpty) {
      slides.add(_MediaSlideItem(isVideo: false, url: _plan!.imageUrl!, title: _plan!.displayName));
    }

    return slides;
  }

  Widget _buildMediaSlider(List<_MediaSlideItem> slides, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 220,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              children: [
                // Swipeable PageView of images & videos
                PageView.builder(
                  controller: _slideController,
                  itemCount: slides.length,
                  onPageChanged: (idx) {
                    setState(() => _activeSlideIndex = idx);
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return GestureDetector(
                      onTap: () => _showMediaPreview(
                        slide.title ?? (slide.isVideo ? 'Plan Video' : 'Plan Photo'),
                        slide.url,
                        slide.isVideo,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (slide.isVideo)
                            _AutoPlayVideoWidget(
                              videoUrl: slide.url,
                              autoPlay: _activeSlideIndex == index,
                              isMuted: true,
                              showControls: true,
                            )
                          else
                            Image.network(
                              slide.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? AppColors.slate800 : AppColors.slate200,
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: AppColors.slate400, size: 40),
                                ),
                              ),
                            ),

                          // Gradient shadow for readable captions
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.75),
                                  ],
                                  stops: const [0.45, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Media Type Pill (Top-Left)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: slide.isVideo ? AppColors.danger : Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    slide.isVideo ? Icons.videocam_rounded : Icons.photo_camera_outlined,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    slide.isVideo ? 'VIDEO GUIDE' : 'PHOTO',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Title & Guidance Caption
                          Positioned(
                            bottom: 16,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slide.title ?? _plan?.displayName ?? 'Health Pass Overview',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (slide.isVideo)
                                  const Text(
                                    'Tap to play video walkthrough',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Slide Counter (Top-Right)
                if (slides.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_activeSlideIndex + 1} / ${slides.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Slide Dots (Bottom-Center)
                if (slides.length > 1)
                  Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _activeSlideIndex == i ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _activeSlideIndex == i ? Colors.white : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _plan!.displayName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        if (_plan!.shortDescription.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _plan!.shortDescription,
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate600,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNoMediaHeroCard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HEALTH & NUTRITION PASS',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                    ),
                  ),
                  const Icon(Icons.verified_outlined, color: Colors.white, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _plan?.displayName ?? 'Health Pass Plan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_plan?.shortDescription.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  _plan!.shortDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MediaSlideItem {
  final bool isVideo;
  final String url;
  final String? title;

  const _MediaSlideItem({
    required this.isVideo,
    required this.url,
    this.title,
  });
}

class _AutoPlayVideoWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool isMuted;
  final bool showControls;

  const _AutoPlayVideoWidget({
    required this.videoUrl,
    this.autoPlay = true,
    this.isMuted = true,
    this.showControls = true,
  });

  @override
  State<_AutoPlayVideoWidget> createState() => _AutoPlayVideoWidgetState();
}

class _AutoPlayVideoWidgetState extends State<_AutoPlayVideoWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _AutoPlayVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay && _controller != null && _isInitialized) {
      if (widget.autoPlay) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (widget.isMuted) {
        await controller.setVolume(0.0);
      } else {
        await controller.setVolume(1.0);
      }
      if (widget.autoPlay && mounted) {
        await controller.play();
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 36),
              SizedBox(height: 6),
              Text('Video preview unavailable', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ),
      );
    }

    final controller = _controller!;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width > 0 ? controller.value.size.width : 16,
              height: controller.value.size.height > 0 ? controller.value.size.height : 9,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (widget.showControls)
          Positioned(
            bottom: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (controller.value.volume > 0) {
                        controller.setVolume(0.0);
                      } else {
                        controller.setVolume(1.0);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      controller.value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

