import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

/// Helper to ensure media URLs (including videos uploaded to local backend)
/// resolve properly across Android Emulators (10.0.2.2), physical devices, iOS, and Web.
String? resolveBannerMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final resolved = AppConfig.resolveMediaUrl(url);
  if (resolved == null) return null;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (resolved.contains('localhost:3000') || resolved.contains('127.0.0.1:3000')) {
      return resolved
          .replaceAll('localhost:3000', '10.0.2.2:3000')
          .replaceAll('127.0.0.1:3000', '10.0.2.2:3000');
    }
  }
  return resolved;
}

/// Global settings configured from the Admin Web Console (/content)
class BannerCarouselSettings {
  final bool autoScrollEnabled;
  final int autoScrollIntervalSeconds;
  final bool showTextOverlay;
  final bool videoAutoplayCarousel;
  final bool videoAutoplayModal;
  final bool videoLoop;
  final bool isMuted;

  const BannerCarouselSettings({
    this.autoScrollEnabled = true,
    this.autoScrollIntervalSeconds = 5,
    this.showTextOverlay = true,
    this.videoAutoplayCarousel = true,
    this.videoAutoplayModal = true,
    this.videoLoop = true,
    this.isMuted = true,
  });

  factory BannerCarouselSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BannerCarouselSettings();
    return BannerCarouselSettings(
      autoScrollEnabled: map['autoScrollEnabled'] != false,
      autoScrollIntervalSeconds:
          (map['autoScrollIntervalSeconds'] as num?)?.toInt() ?? 5,
      showTextOverlay: map['showTextOverlay'] != false,
      videoAutoplayCarousel: map['videoAutoplayCarousel'] != false,
      videoAutoplayModal: map['videoAutoplayModal'] != false,
      videoLoop: map['videoLoop'] != false,
      isMuted: map['isMuted'] != false,
    );
  }
}

class BannerMediaItem {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final String imageUrl;
  final bool isVideo;
  final String? videoUrl;
  final String? videoDuration;
  final bool autoPlay;
  final bool isMuted;
  final bool showTextOverlay;
  final String? targetRoute;
  final Map<String, dynamic>? routeArguments;
  final String? ctaText;

  const BannerMediaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.imageUrl,
    this.isVideo = false,
    this.videoUrl,
    this.videoDuration,
    this.autoPlay = true,
    this.isMuted = true,
    this.showTextOverlay = true,
    this.targetRoute,
    this.routeArguments,
    this.ctaText,
  });
}

class AutoScrollBannerCarousel extends StatefulWidget {
  /// Banners configured in the admin console (Content → Home Banners).
  final List<BannerMediaItem> banners;

  /// Global carousel behavior settings (scroll speed, text visibility, video autoplay)
  final BannerCarouselSettings settings;

  const AutoScrollBannerCarousel({
    super.key,
    required this.banners,
    this.settings = const BannerCarouselSettings(),
  });

  @override
  State<AutoScrollBannerCarousel> createState() => _AutoScrollBannerCarouselState();
}

class _AutoScrollBannerCarouselState extends State<AutoScrollBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  int _currentPage = 0;
  bool _isUserInteracting = false;

  List<BannerMediaItem> get _banners => widget.banners;

  @override
  void initState() {
    super.initState();
    final hasMultiple = _banners.length > 1;
    _pageController = PageController(viewportFraction: hasMultiple ? 0.90 : 1.0);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AutoScrollBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.autoScrollEnabled != widget.settings.autoScrollEnabled ||
        oldWidget.settings.autoScrollIntervalSeconds != widget.settings.autoScrollIntervalSeconds ||
        oldWidget.banners.length != widget.banners.length) {
      _startTimer();
    }
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    if (!widget.settings.autoScrollEnabled || _banners.length <= 1) return;

    final seconds = widget.settings.autoScrollIntervalSeconds.clamp(2, 60);
    _autoScrollTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (_isUserInteracting || !mounted || _banners.isEmpty) return;
      if (!_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  IconData _getBannerIcon(String id) {
    switch (id) {
      case 'chef_story':
      case 'banner_artisan_chefs':
        return Icons.soup_kitchen_rounded;
      case 'dietitian_care':
      case 'dietitian_consult':
      case 'banner_healthpass_pro':
        return Icons.health_and_safety_rounded;
      case 'health_pass_offer':
        return Icons.workspace_premium_rounded;
      case 'curated_thali':
        return Icons.restaurant_menu_rounded;
      case 'banner_video_showcase':
        return Icons.videocam_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  void _handleBannerTap(BannerMediaItem banner) {
    if (banner.isVideo) {
      _showVideoPreviewSheet(banner);
    } else if (banner.targetRoute != null && banner.targetRoute!.isNotEmpty) {
      Navigator.pushNamed(context, banner.targetRoute!, arguments: banner.routeArguments);
    }
  }

  void _showVideoPreviewSheet(BannerMediaItem banner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BannerVideoSheet(
        banner: banner,
        settings: widget.settings,
        getBannerIcon: _getBannerIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is ScrollStartNotification) {
                _isUserInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _isUserInteracting = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              padEnds: false,
              physics: const ClampingScrollPhysics(),
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                _currentPageNotifier.value = index;
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final isLast = index == _banners.length - 1;
                final isCurrentActive = index == _currentPage;
                final shouldShowText = widget.settings.showTextOverlay && banner.showTextOverlay;

                return Padding(
                  padding: EdgeInsets.only(
                    right: (_banners.length > 1 && !isLast) ? 12 : 0,
                  ),
                  child: InkWell(
                    onTap: () => _handleBannerTap(banner),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Card Media: Inline Video Player (when active & autoplay on) or Network Image
                            _BannerCardMedia(
                              banner: banner,
                              isActive: isCurrentActive,
                              settings: widget.settings,
                            ),

                            // Multi-Layer Contrast Scrim Gradient (Only when text overlay is enabled)
                            if (shouldShowText)
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.48),
                                      Colors.black.withOpacity(0.88),
                                    ],
                                    stops: const [0.0, 0.40, 0.72, 1.0],
                                  ),
                                ),
                              ),

                            // Top video indicator icon when text overlay is hidden so users still know it's a video
                            if (!shouldShowText && banner.isVideo)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'VIDEO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Content Container with Proper Internal Spacing (Only when text overlay is enabled)
                            if (shouldShowText)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top Row: Tag Pill & Action Cue
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Pill Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            color: banner.tagColor.withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getBannerIcon(banner.id),
                                                color: Colors.white,
                                                size: 11.5,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                banner.tag,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        if (banner.isVideo)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.play_circle_fill_rounded,
                                                  color: Colors.white,
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  banner.videoDuration ?? 'Story',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  banner.ctaText ?? 'Explore',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                const Icon(
                                                  Icons.arrow_forward_ios_rounded,
                                                  color: Colors.white,
                                                  size: 9,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Bottom Text Hierarchy
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 3.5,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: banner.tagColor,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                banner.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.2,
                                                  height: 1.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 11.5),
                                          child: Text(
                                            banner.subtitle,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.88),
                                              fontSize: 11.5,
                                              height: 1.25,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Indicator Dots
        ValueListenableBuilder<int>(
          valueListenable: _currentPageNotifier,
          builder: (context, currentPage, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (idx) {
                final isSelected = idx == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 22 : 6,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.slate700 : AppColors.slate300),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

/// Renders either an inline muted looping video (if active & autoplay on) or the photography poster
class _BannerCardMedia extends StatefulWidget {
  final BannerMediaItem banner;
  final bool isActive;
  final BannerCarouselSettings settings;

  const _BannerCardMedia({
    required this.banner,
    required this.isActive,
    required this.settings,
  });

  @override
  State<_BannerCardMedia> createState() => _BannerCardMediaState();
}

class _BannerCardMediaState extends State<_BannerCardMedia> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.banner.isVideo && widget.settings.videoAutoplayCarousel && widget.isActive) {
      _initInlineVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _BannerCardMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.banner.isVideo || !widget.settings.videoAutoplayCarousel) {
      _disposeInlineVideo();
      return;
    }

    if (widget.isActive && !oldWidget.isActive) {
      if (_videoController == null) {
        _initInlineVideo();
      } else if (_isVideoInitialized) {
        _videoController?.play();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _videoController?.pause();
    }
  }

  Future<void> _initInlineVideo() async {
    final rawUrl = widget.banner.videoUrl;
    final resolvedUrl = resolveBannerMediaUrl(rawUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) return;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(widget.settings.videoLoop);
      await controller.setVolume(0.0); // Always muted for carousel motion
      if (mounted && widget.isActive) {
        await controller.play();
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (_) {
      // Graceful fallback to static poster image
    }
  }

  void _disposeInlineVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
  }

  @override
  void dispose() {
    _disposeInlineVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = resolveBannerMediaUrl(widget.banner.imageUrl) ?? widget.banner.imageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Poster Image
        Image.network(
          resolvedImageUrl,
          cacheWidth: 800,
          cacheHeight: 400,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.slate800,
            child: const Icon(Icons.image_not_supported_rounded, color: Colors.white38),
          ),
        ),

        // Inline Video Player overlay (smooth crossfade when ready)
        if (_isVideoInitialized && _videoController != null)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width > 0
                    ? _videoController!.value.size.width
                    : 16,
                height: _videoController!.value.size.height > 0
                    ? _videoController!.value.size.height
                    : 9,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full interactive video player bottom sheet with controls, scrubbing, mute toggle, and retry
class _BannerVideoSheet extends StatefulWidget {
  final BannerMediaItem banner;
  final BannerCarouselSettings settings;
  final IconData Function(String) getBannerIcon;

  const _BannerVideoSheet({
    required this.banner,
    required this.settings,
    required this.getBannerIcon,
  });

  @override
  State<_BannerVideoSheet> createState() => _BannerVideoSheetState();
}

class _BannerVideoSheetState extends State<_BannerVideoSheet> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMuted = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.settings.isMuted;
    _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final rawUrl = widget.banner.videoUrl;
    final resolvedUrl = resolveBannerMediaUrl(rawUrl);

    if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No video URL specified for this banner.';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      _controller = controller;

      controller.addListener(_videoListener);
      await controller.initialize();
      await controller.setLooping(widget.settings.videoLoop);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      if (widget.settings.videoAutoplayModal && widget.banner.autoPlay) {
        await controller.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        _scheduleHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to stream video. Tap below to retry.';
        });
      }
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (_controller?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _scheduleHideControls();
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banner = widget.banner;
    final resolvedPoster = resolveBannerMediaUrl(banner.imageUrl) ?? banner.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tag row + close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: banner.tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.getBannerIcon(banner.id), color: banner.tagColor, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      banner.tag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: banner.tagColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(banner.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            banner.subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 14),

          // Video Player Area
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) _scheduleHideControls();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video stream or poster image
                    if (_isInitialized && _controller != null)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width > 0
                                ? _controller!.value.size.width
                                : 16,
                            height: _controller!.value.size.height > 0
                                ? _controller!.value.size.height
                                : 9,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    else
                      Image.network(
                        resolvedPoster,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.slate800,
                          child: const Center(
                            child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
                          ),
                        ),
                      ),

                    // Loading overlay
                    if (_isLoading)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        ),
                      ),

                    // Error overlay with Retry button
                    if (_hasError)
                      Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage ?? 'Failed to play video',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retry Playback'),
                                onPressed: _initVideo,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Controls overlay
                    if (_isInitialized && _controller != null && (_showControls || !_controller!.value.isPlaying)) ...[
                      // Dim scrim
                      Container(color: Colors.black38),

                      // Center Play/Pause button
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 12),
                            ],
                          ),
                          child: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.primaryDark,
                            size: 34,
                          ),
                        ),
                      ),

                      // Mute toggle (top right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              _controller!.setVolume(_isMuted ? 0.0 : 1.0);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),

                      // Bottom Progress Scrubber
                      Positioned(
                        bottom: 8,
                        left: 12,
                        right: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controller!.value.position),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatDuration(_controller!.value.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            VideoProgressIndicator(
                              _controller!,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              colors: VideoProgressColors(
                                playedColor: AppColors.primary,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // CTA Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                banner.ctaText ?? 'Explore Full Experience',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (banner.targetRoute != null && banner.targetRoute!.isNotEmpty) {
                  Navigator.pushNamed(context, banner.targetRoute!, arguments: banner.routeArguments);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
