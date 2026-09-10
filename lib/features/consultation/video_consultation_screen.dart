import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_button.dart';

class VideoConsultationScreen extends StatefulWidget {
  final ConsultationModel consultation;

  const VideoConsultationScreen({super.key, required this.consultation});

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isEnded = false;

  void _endCall() {
    setState(() => _isEnded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEnded) {
      return _buildCompletedView();
    }

    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: SafeArea(
        child: Stack(
          children: [
            // Dietitian Full-Screen Video Area (Simulated WebRTC Feed)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 70, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.consultation.dietitianName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Clinical Nutrition Consultation • Live Encrypted',
                    style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 12),
                        SizedBox(width: 6),
                        Text('14:32', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Top bar
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'For: ${widget.consultation.memberName}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Customer Small Video Pip (Bottom-Right)
            Positioned(
              right: 20,
              bottom: 120,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Center(
                  child: _isVideoOff
                      ? const Icon(Icons.videocam_off, color: Colors.white54)
                      : const Icon(Icons.person, color: Colors.white54, size: 40),
                ),
              ),
            ),

            // Section 20 Controls: [ Mute ] [ Camera ] [ Speaker ] [ End ]
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _buildCallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  // Camera
                  _buildCallButton(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    label: _isVideoOff ? 'Video On' : 'Camera',
                    isActive: _isVideoOff,
                    onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                  ),
                  // Speaker
                  _buildCallButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                  // End
                  _buildCallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    bgColor: AppColors.danger,
                    iconColor: Colors.white,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? bgColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor ?? (isActive ? Colors.white : AppColors.slate800),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isActive ? AppColors.slate900 : Colors.white),
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // Section 20 "After completion: Consultation Completed, [ View Summary ], [ View Diet Plan ]"
  Widget _buildCompletedView() {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Consultation Completed'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 50),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Consultation Completed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              Text(
                'Your session with ${widget.consultation.dietitianName} has concluded. Your personalized diet plan is being updated with clinical notes.',
                style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              EbicButton(
                label: 'View Consultation Summary',
                icon: Icons.notes_outlined,
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.consultationSummary,
                    arguments: {'consultation': widget.consultation},
                  );
                },
              ),
              const SizedBox(height: 12),

              EbicButton(
                label: 'View Diet Plan',
                icon: Icons.restaurant_menu_rounded,
                variant: EbicButtonVariant.outline,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.dietPlan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
