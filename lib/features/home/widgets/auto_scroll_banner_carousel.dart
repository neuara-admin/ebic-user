import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routing/app_routes.dart';

class BannerMediaItem {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final String imageUrl;
  final bool isVideo;
  final String? videoDuration;
  final String? targetRoute;
  final Map<String, dynamic>? routeArguments;

  const BannerMediaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.imageUrl,
    this.isVideo = false,
    this.videoDuration,
    this.targetRoute,
    this.routeArguments,
  });
}

class AutoScrollBannerCarousel extends StatefulWidget {
  final List<BannerMediaItem>? customBanners;

  const AutoScrollBannerCarousel({super.key, this.customBanners});

  @override
  State<AutoScrollBannerCarousel> createState() => _AutoScrollBannerCarouselState();
}

class _AutoScrollBannerCarouselState extends State<AutoScrollBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  int _currentPage = 0;
  bool _isUserInteracting = false;

  final List<BannerMediaItem> _defaultBanners = const [
    BannerMediaItem(
      id: 'chef_story',
      title: 'Private Executive Chef Experience',
      subtitle: 'Gourmet healthy recipes cooked fresh live in your kitchen with your own cookware.',
      tag: 'CHEF AT HOME',
      tagColor: Color(0xFF059669),
      imageUrl: 'https://images.unsplash.com/photo-1577219491135-ce391730fb2c?auto=format&fit=crop&w=800&q=80',
      isVideo: true,
      videoDuration: '0:45',
      targetRoute: AppRoutes.bookChef,
    ),
    BannerMediaItem(
      id: 'dietitian_consult',
      title: 'Personalized Clinical Nutrition',
      subtitle: 'Board-certified clinical dietitians tailoring meal charts for diabetes, PCOS, and gut health.',
      tag: 'CLINICAL CARE',
      tagColor: Color(0xFF2563EB),
      imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=800&q=80',
      isVideo: true,
      videoDuration: '1:10',
      targetRoute: AppRoutes.dietitian,
    ),
    BannerMediaItem(
      id: 'health_pass_offer',
      title: 'EBIC Health Pass • Save Up to 35%',
      subtitle: 'All-inclusive in-home chef visits + 1-on-1 clinical nutrition care for your family.',
      tag: 'HEALTH PASS',
      tagColor: Color(0xFFD97706),
      imageUrl: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      targetRoute: AppRoutes.healthPassPlans,
    ),
    BannerMediaItem(
      id: 'curated_thali',
      title: 'Dietitian-Approved Everyday Thali',
      subtitle: 'Customized macros, wholesome millets, and farm-fresh greens prepared to perfection.',
      tag: 'NUTRITION FIRST',
      tagColor: Color(0xFF7C3AED),
      imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      targetRoute: AppRoutes.bookChefCatalogue,
    ),
  ];

  List<BannerMediaItem> get _banners => widget.customBanners ?? _defaultBanners;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
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

  void _handleBannerTap(BannerMediaItem banner) {
    if (banner.isVideo) {
      _showVideoPreviewSheet(banner);
    } else if (banner.targetRoute != null) {
      Navigator.pushNamed(context, banner.targetRoute!, arguments: banner.routeArguments);
    }
  }

  void _showVideoPreviewSheet(BannerMediaItem banner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: banner.tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      banner.tag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: banner.tagColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                banner.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                banner.subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.35),
              ),
              const SizedBox(height: 16),
              // Simulated HD Video Player Viewport
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      banner.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: AppColors.slate800,
                        child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 48),
                      ),
                    ),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryDark, size: 34),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.hd_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('1080p EBIC Spotlight', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              banner.videoDuration ?? '1:00',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                  label: const Text('Explore Full Experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (banner.targetRoute != null) {
                      Navigator.pushNamed(context, banner.targetRoute!, arguments: banner.routeArguments);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 182,
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
              physics: const ClampingScrollPhysics(),
              itemCount: _banners.length,
              onPageChanged: (index) {
                _currentPage = index;
                _currentPageNotifier.value = index;
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    onTap: () => _handleBannerTap(banner),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: banner.tagColor.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
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

                            // Multi-Layer Contrast Gradient Overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.black.withValues(alpha: 0.88),
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: banner.tagColor,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: banner.tagColor.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          banner.tag,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                      if (banner.isVideo)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Tap to view',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                              ),
                                              SizedBox(width: 3),
                                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 9),
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
                                      Text(
                                        banner.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          height: 1.2,
                                          shadows: [
                                            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        banner.subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                          height: 1.35,
                                          shadows: const [
                                            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 12),

        // Indicator Dots (driven by ValueListenableBuilder for zero rebuild jank)
        ValueListenableBuilder<int>(
          valueListenable: _currentPageNotifier,
          builder: (context, currentPage, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (idx) {
                final isSelected = idx == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 20 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.slate300,
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
