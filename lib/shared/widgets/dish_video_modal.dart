import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';

class DishVideoModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const DishVideoModal({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  static void show(BuildContext context, {required String videoUrl, required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DishVideoModal(videoUrl: videoUrl, title: title),
    );
  }

  @override
  State<DishVideoModal> createState() => _DishVideoModalState();
}

class _DishVideoModalState extends State<DishVideoModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (_) {
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

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'PREPARATION VIDEO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: _isInitialized ? _controller!.value.aspectRatio : (16 / 9),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInitialized && _controller != null)
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: VideoPlayer(_controller!),
                      )
                    else if (_hasError)
                      Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.play_disabled_rounded, size: 36, color: Colors.white54),
                              SizedBox(height: 8),
                              Text(
                                'Video preview temporarily unavailable',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                    if (_isInitialized && !_isPlaying)
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isInitialized && _controller != null) ...[
              const SizedBox(height: 8),
              VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live cooking demo & culinary technique demonstrated by certified EBIC chefs.',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
