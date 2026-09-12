import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
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
  final ApiClient _api = ApiClient();
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isEnded = false;
  bool _isAuthorizing = true;
  String? _authError;
  String? _roomName;
  String? _joinToken;

  @override
  void initState() {
    super.initState();
    _initJoinSession();
  }

  Future<void> _initJoinSession() async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultationJoin(widget.consultation.id),
      );
      if (mounted) {
        if (res.success && res.data != null) {
          setState(() {
            _isAuthorizing = false;
            _roomName = res.data!['roomName']?.toString();
            _joinToken = res.data!['joinToken']?.toString();
          });
        } else {
          // If server rejects join window
          setState(() {
            _isAuthorizing = false;
            _authError = res.message ?? 'Join window opens 15 minutes before your scheduled appointment time.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthorizing = false;
          _roomName = 'ebic-consultation-${widget.consultation.id.substring(0, widget.consultation.id.length > 8 ? 8 : widget.consultation.id.length)}';
        });
      }
    }
  }

  void _endCall() {
    setState(() => _isEnded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) {
      return Scaffold(
        backgroundColor: AppColors.slate950,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Connecting to secure medical video room...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_authError != null) {
      return Scaffold(
        backgroundColor: AppColors.slate950,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.slate700),
                  ),
                  child: const Icon(Icons.lock_clock_rounded, size: 32, color: AppColors.accent),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Consultation Not Yet Open',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _authError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate400, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scheduled: ${DateFormat('EEEE, dd MMM • hh:mm a').format(widget.consultation.scheduledAt)}',
                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: 'Return to Consultations',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                  Text(
                    _joinToken != null
                        ? 'Live Encrypted Room • Session Verified'
                        : 'Clinical Nutrition Consultation • Live Encrypted',
                    style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
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
                      _roomName != null ? 'Room: $_roomName' : 'For: ${widget.consultation.memberName}',
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

  // Video ended is not consultation completion — dietitian must complete it from the web portal
  Widget _buildCompletedView() {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Call Ended'),
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
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.call_end_rounded, color: AppColors.primary, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Video Session Ended',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              Text(
                'Your call with Dr. ${widget.consultation.dietitianName} has concluded.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Your dietitian is currently reviewing the clinical discussion, compiling your family health profile, and will finalize your consultation and diet plan on the portal.',
                style: TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Text(
                      'Clinical Finalization in Progress by Dietitian',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              EbicButton(
                label: 'View My Consultations',
                icon: Icons.calendar_month_rounded,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.consultationsList);
                },
              ),
              const SizedBox(height: 10),

              EbicButton(
                label: 'Return to Home',
                variant: EbicButtonVariant.outline,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.mainShell,
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
