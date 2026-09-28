import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_button.dart';

/// Video call for a dietitian consultation, backed by Agora RTC. The
/// backend's `/consultations/:id/join` returns the Agora app id, the
/// consultation's channel, and a signed token for this customer — this
/// screen joins that channel and renders both video feeds itself.
class VideoConsultationScreen extends StatefulWidget {
  final ConsultationModel consultation;

  const VideoConsultationScreen({super.key, required this.consultation});

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  final ApiClient _api = ApiClient();

  RtcEngine? _engine;
  String? _channelName;
  int? _expectedRemoteUid;
  int? _remoteUid;
  bool _remoteVideoOn = false;
  bool _remoteLeft = false;

  bool _isAuthorizing = true;
  bool _isJoined = false;
  bool _isReconnecting = false;
  bool _isEnded = false;
  String? _authError;
  String? _authErrorCode;

  bool _micOn = true;
  bool _camOn = true;
  bool _hasCameraPermission = true;

  Timer? _ticker;
  DateTime? _joinedAt;
  Duration _elapsed = Duration.zero;

  String get _dietitianName => widget.consultation.dietitianName;

  @override
  void initState() {
    super.initState();
    _initJoinSession();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _disposeEngine();
    super.dispose();
  }

  Future<void> _initJoinSession() async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultationJoin(widget.consultation.id),
      );
      if (!mounted) return;

      if (res.success && res.data != null) {
        await _startCall(res.data!);
      } else {
        setState(() {
          _isAuthorizing = false;
          _authErrorCode = res.error?.code;
          _authError = res.error?.message ?? res.message ?? 'Unable to join the consultation right now.';
        });
      }
    } catch (e, stack) {
      debugPrint('❌ [VideoConsultation] Failed to join consultation ${widget.consultation.id}: $e\n$stack');
      await _disposeEngine();
      if (mounted) {
        setState(() {
          _isAuthorizing = false;
          _authError = 'Unable to join the consultation. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _startCall(Map<String, dynamic> data) async {
    final appId = data['appId']?.toString() ?? '';
    final channelName = data['channelName']?.toString() ?? '';
    final token = data['token']?.toString() ?? '';
    final uid = (data['uid'] as num?)?.toInt() ?? 0;
    final remoteUid = (data['remoteUid'] as num?)?.toInt();

    if (appId.isEmpty || channelName.isEmpty) {
      throw StateError('Join response is missing Agora appId/channelName: $data');
    }

    final statuses = await [Permission.microphone, Permission.camera].request();
    if (!(statuses[Permission.microphone]?.isGranted ?? false)) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        _authErrorCode = 'PERMISSION_DENIED';
        _authError = 'Microphone access is needed to talk to your dietitian. Allow it in Settings, then try again.';
      });
      return;
    }
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

    final engine = createAgoraRtcEngine();
    _engine = engine;
    _channelName = channelName;
    _expectedRemoteUid = remoteUid;

    await engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (!mounted) return;
        setState(() {
          _isJoined = true;
          _joinedAt = DateTime.now();
        });
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _joinedAt != null) {
            setState(() => _elapsed = DateTime.now().difference(_joinedAt!));
          }
        });
      },
      onUserJoined: (connection, joinedUid, elapsed) {
        if (!mounted) return;
        if (_expectedRemoteUid != null && joinedUid != _expectedRemoteUid) return;
        setState(() {
          _remoteUid = joinedUid;
          _remoteLeft = false;
        });
      },
      onUserOffline: (connection, offlineUid, reason) {
        if (!mounted || offlineUid != _remoteUid) return;
        setState(() {
          _remoteUid = null;
          _remoteVideoOn = false;
          _remoteLeft = true;
        });
        _endIfDietitianEndedCall();
      },
      onRemoteVideoStateChanged: (connection, videoUid, state, reason, elapsed) {
        if (!mounted || videoUid != _remoteUid) return;
        setState(() {
          _remoteVideoOn = state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting ||
              state == RemoteVideoState.remoteVideoStateFrozen;
        });
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (!mounted) return;
        setState(() => _isReconnecting = state == ConnectionStateType.connectionStateReconnecting);
        if (state == ConnectionStateType.connectionStateFailed) {
          _handleFatalCallError('The call connection was lost. Please rejoin.');
        }
      },
      onTokenPrivilegeWillExpire: (connection, expiringToken) => _renewToken(),
      onError: (err, msg) => debugPrint('⚠️ [VideoConsultation] Agora error $err: $msg'),
    ));

    await engine.setDefaultAudioRouteToSpeakerphone(true);
    await engine.enableVideo();
    if (cameraGranted) {
      await engine.startPreview();
    } else {
      await engine.enableLocalVideo(false);
    }

    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: cameraGranted,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isAuthorizing = false;
      _hasCameraPermission = cameraGranted;
      _camOn = cameraGranted;
    });
  }

  Future<void> _renewToken() async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.consultationJoin(widget.consultation.id),
    );
    final newToken = res.data?['token']?.toString();
    if (res.success && newToken != null && newToken.isNotEmpty) {
      await _engine?.renewToken(newToken);
    }
  }

  /// The dietitian leaving the channel is either a dropped connection (stay
  /// and wait) or them ending the call for everyone (status becomes
  /// VIDEO_COMPLETED) — only the latter should close the call here.
  Future<void> _endIfDietitianEndedCall() async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.consultation(widget.consultation.id));
    final status = res.data?['status']?.toString();
    if (!mounted || _isEnded) return;
    if (status == 'VIDEO_COMPLETED' || status == 'COMPLETED' || status == 'CANCELLED') {
      await _endCall();
    }
  }

  Future<void> _handleFatalCallError(String message) async {
    await _disposeEngine();
    if (!mounted) return;
    setState(() {
      _authError = message;
      _authErrorCode = 'CONNECTION_FAILED';
    });
  }

  Future<void> _disposeEngine() async {
    final engine = _engine;
    _engine = null;
    _ticker?.cancel();
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (_) {}
    try {
      await engine.release();
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    await _engine?.muteLocalAudioStream(_micOn);
    setState(() => _micOn = !_micOn);
  }

  Future<void> _toggleCamera() async {
    if (!_hasCameraPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access is off. Enable it in Settings to share video.')),
      );
      return;
    }
    await _engine?.enableLocalVideo(!_camOn);
    await _engine?.muteLocalVideoStream(_camOn);
    setState(() => _camOn = !_camOn);
  }

  Future<void> _switchCamera() async {
    if (_camOn) await _engine?.switchCamera();
  }

  Future<void> _endCall() async {
    await _disposeEngine();
    if (!mounted) return;
    setState(() => _isEnded = true);
  }

  /// Re-enters the same channel (the backend derives one deterministic
  /// channel per consultation and re-mints a fresh token on every join) —
  /// this is what lets the customer get back in after an accidental
  /// disconnect or a mistaken hang-up, without the dietitian doing anything.
  Future<void> _rejoinCall() async {
    await _disposeEngine();
    if (!mounted) return;
    setState(() {
      _isEnded = false;
      _isAuthorizing = true;
      _isJoined = false;
      _isReconnecting = false;
      _authError = null;
      _authErrorCode = null;
      _remoteUid = null;
      _remoteVideoOn = false;
      _remoteLeft = false;
      _micOn = true;
      _joinedAt = null;
      _elapsed = Duration.zero;
    });
    _initJoinSession();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) return _buildConnectingView();
    if (_authError != null) return _buildErrorView();
    if (_isEnded) return _buildCompletedView();
    return _buildCallView();
  }

  Widget _buildConnectingView() {
    return const Scaffold(
      backgroundColor: AppColors.slate950,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Connecting to secure medical video room...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallView() {
    final engine = _engine;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildRemoteVideo(engine)),

            // Top bar: who you're talking to and how long.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 140, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. $_dietitianName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isReconnecting
                          ? 'Reconnecting…'
                          : _isJoined
                              ? 'Video consultation • ${_formatElapsed(_elapsed)}'
                              : 'Connecting…',
                      style: TextStyle(
                        color: _isReconnecting ? const Color(0xFFFBBF24) : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Self-view (picture-in-picture).
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 108,
                  height: 152,
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: (_camOn && engine != null)
                      ? AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: engine,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
                        ),
                ),
              ),
            ),

            // Controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      label: _micOn ? 'Mute' : 'Unmute',
                      active: _micOn,
                      onTap: _toggleMic,
                    ),
                    _controlButton(
                      icon: _camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      label: _camOn ? 'Camera' : 'Camera off',
                      active: _camOn,
                      onTap: _toggleCamera,
                    ),
                    _controlButton(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Flip',
                      active: true,
                      onTap: _switchCamera,
                    ),
                    _controlButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      active: true,
                      background: const Color(0xFFDC2626),
                      onTap: _endCall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo(RtcEngine? engine) {
    final remoteUid = _remoteUid;
    if (engine != null && remoteUid != null && _remoteVideoOn && _channelName != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: remoteUid, renderMode: RenderModeType.renderModeFit),
          connection: RtcConnection(channelId: _channelName),
        ),
      );
    }

    final String message;
    if (remoteUid != null) {
      message = 'Dr. $_dietitianName\'s camera is off';
    } else if (_remoteLeft) {
      message = 'Dr. $_dietitianName left the call.\nStay here — they can rejoin at any time.';
    } else {
      message = 'Waiting for Dr. $_dietitianName to join…';
    }

    return Container(
      color: AppColors.slate950,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(_dietitianName),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          if (remoteUid == null) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? background,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background ?? (active ? Colors.white.withValues(alpha: 0.16) : Colors.white),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                icon,
                color: background != null || active ? Colors.white : AppColors.slate900,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildErrorView() {
    final code = _authErrorCode;
    final String title;
    final IconData icon;
    switch (code) {
      case 'CALL_NOT_STARTED':
        title = 'Waiting for Your Dietitian';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'JOIN_WINDOW_CLOSED':
      case 'JOIN_WINDOW_EXPIRED':
        title = 'Consultation Not Open';
        icon = Icons.lock_clock_rounded;
        break;
      case 'PERMISSION_DENIED':
        title = 'Microphone Access Needed';
        icon = Icons.mic_off_rounded;
        break;
      case 'CALL_ENDED':
        title = 'Video Consultation Done';
        icon = Icons.pending_actions_rounded;
        break;
      default:
        title = 'Unable to Join the Call';
        icon = Icons.videocam_off_rounded;
    }
    final canRetry = code == 'CALL_NOT_STARTED' || code == 'CONNECTION_FAILED' || code == null;

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
                child: Icon(icon, size: 32, color: AppColors.accent),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
              if (code == 'PERMISSION_DENIED') ...[
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: 'Open Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () => openAppSettings(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (canRetry || code == 'PERMISSION_DENIED') ...[
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: code == 'CALL_NOT_STARTED' ? 'Check Again' : 'Try Again',
                    icon: Icons.refresh_rounded,
                    variant: code == 'PERMISSION_DENIED' ? EbicButtonVariant.outline : EbicButtonVariant.primary,
                    onPressed: _rejoinCall,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'Return to Consultations',
                  variant: EbicButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.call_end_rounded, color: AppColors.primary, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You\'ve Left the Call',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 8),
              Text(
                'Your video call with ${_dietitianName.toLowerCase().startsWith('dr') ? _dietitianName : 'Dr. $_dietitianName'} has ended on your side.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Once your dietitian saves their notes, you\'ll find them in your consultation details — we\'ll notify you.',
                style: TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              EbicButton(
                label: 'Rejoin Video Call',
                icon: Icons.replay_rounded,
                onPressed: _rejoinCall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Left by mistake or got disconnected? You can rejoin the same session until your dietitian marks it complete.',
                style: TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              EbicButton(
                label: 'View My Consultations',
                variant: EbicButtonVariant.outline,
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
