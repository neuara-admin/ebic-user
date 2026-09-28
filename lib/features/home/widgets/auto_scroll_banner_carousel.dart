import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';

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
    this.isMuted = false,
    this.targetRoute,
    this.routeArguments,
    this.ctaText,
  });
}

class AutoScrollBannerCarousel extends StatefulWidget {
  /// Banners configured in the admin console (Content → Home Banners).
  final List<BannerMediaItem> banners;

  const AutoScrollBannerCarousel({super.key, required this.banners});

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
    // padEnds: false + viewportFraction: 0.90 ensures:
    // 1. The active card aligns flush at the left margin (16px from screen edge)
    // 2. The next card peeks in gracefully from the right edge with a 12px gap
    final hasMultiple = _banners.length > 1;
    _pageController = PageController(viewportFraction: hasMultiple ? 0.90 : 1.0);
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
        return Icons.soup_kitchen_rounded;
      case 'dietitian_care':
      case 'dietitian_consult':
        return Icons.health_and_safety_rounded;
      case 'health_pass_offer':
        return Icons.workspace_premium_rounded;
      case 'curated_thali':
        return Icons.restaurant_menu_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  void _handleBannerTap(BannerMediaItem banner) {
    if (banner.isVideo) {
      _showVideoPreviewSheet(banner);
    } else if (banner.targetRoute != null) {
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
          height: 186,
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
                _currentPage = index;
                _currentPageNotifier.value = index;
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final isLast = index == _banners.length - 1;
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
                      // Soft, premier multi-layered neutral drop shadows — no muddy colored blur
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
                          // High-Res Background Image with memory optimization
                          Image.network(
                            banner.imageUrl,
                            cacheWidth: 800,
                            cacheHeight: 400,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.slate800,
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.white38),
                            ),
                          ),

                          // Multi-Layer Contrast Scrim Gradient Overlay for crystal clear typography
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.10),
                                  Colors.black.withValues(alpha: 0.30),
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.black.withValues(alpha: 0.94),
                                ],
                                stops: const [0.0, 0.35, 0.70, 1.0],
                              ),
                            ),
                          ),

                          // Content Container with Proper Internal Spacing
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
                                    // Elegant Pill Badge
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
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 13),
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
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
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
                                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 9),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Bottom Text Hierarchy with Clean Vertical Accent
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
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                        maxLines: 2,
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

        // Indicator Dots (driven by ValueListenableBuilder for zero rebuild jank)
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

/// Real video player bottom sheet for banner video banners.
class _BannerVideoSheet extends StatefulWidget {
  final BannerMediaItem banner;
  final IconData Function(String) getBannerIcon;

  const _BannerVideoSheet({required this.banner, required this.getBannerIcon});

  @override
  State<_BannerVideoSheet> createState() => _BannerVideoSheetState();
}

class _BannerVideoSheetState extends State<_BannerVideoSheet> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.banner.isMuted;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.banner.videoUrl;
    if (url == null || url.trim().isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.banner.isMuted ? 0.0 : 1.0);
      if (widget.banner.autoPlay) await controller.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banner = widget.banner;

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
          // Handle bar
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

          // Video player / poster / loading
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background: real player or poster image
                  if (_isInitialized && _controller != null)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                          height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  else
                    Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.slate800,
                        child: const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40)),
                      ),
                    ),

                  // Dark overlay when not yet playing
                  if (!_isInitialized)
                    Container(color: Colors.black.withValues(alpha: 0.45)),

                  // Loading spinner
                  if (!_isInitialized && !_hasError)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    ),

                  // Error state
                  if (_hasError)
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 36),
                        SizedBox(height: 6),
                        Text('Video unavailable', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),

                  // Controls overlay (only when playing)
                  if (_isInitialized && _controller != null) ...[
                    // Mute/unmute
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
                    // Tap to play/pause
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryDark, size: 34),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // CTA button
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
                if (banner.targetRoute != null) {
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
