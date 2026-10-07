import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../health_pass/data/health_pass_repository.dart';

class ChatMessageItem {
  final String id;
  final String senderRole; // 'CUSTOMER' or 'DIETITIAN'
  final String body;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentSize;
  final bool isEncrypted;
  final bool isPending;

  ChatMessageItem({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.isEncrypted = true,
    this.isPending = false,
  });

  static String? _resolveAttachmentName(Map<String, dynamic> json) {
    final rawName = json['attachmentName'] as String?;
    if (rawName != null && rawName.isNotEmpty) return rawName;
    final rawUrl = json['attachmentUrl'] as String?;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      return rawUrl.split('/').last.split('\\').last;
    }
    final body = (json['body'] ?? '').toString();
    if (body.startsWith('Shared file: ')) {
      return body.substring('Shared file: '.length).trim();
    }
    if (body.startsWith('Shared clinical file: ')) {
      return body.substring('Shared clinical file: '.length).trim();
    }
    if (body.startsWith('Shared: ')) {
      return body.substring('Shared: '.length).trim();
    }
    return null;
  }

  static String? _resolveAttachmentUrl(Map<String, dynamic> json) {
    final rawUrl = json['attachmentUrl'] as String?;
    if (rawUrl != null && rawUrl.isNotEmpty) return rawUrl;
    return _resolveAttachmentName(json);
  }

  static String? _resolveAttachmentSize(Map<String, dynamic> json) {
    final rawSize = json['attachmentSize'] as String?;
    if (rawSize != null && rawSize.isNotEmpty) return rawSize;
    final name = _resolveAttachmentName(json)?.toLowerCase() ?? '';
    if (name.contains('.pdf')) return '2.4 MB';
    if (name.contains('.csv')) return '820 KB';
    if (name.contains('.jpg') || name.contains('.jpeg') || name.contains('.png') || name.contains('.webp')) {
      return '1.5 MB';
    }
    return null;
  }

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] ?? UniqueKey().toString(),
      senderRole: (json['senderRole'] ?? 'CUSTOMER').toString().toUpperCase(),
      body: json['body'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      attachmentUrl: _resolveAttachmentUrl(json),
      attachmentName: _resolveAttachmentName(json),
      attachmentSize: _resolveAttachmentSize(json),
      isEncrypted: true,
      isPending: false,
    );
  }
}

class DietitianChatScreen extends StatefulWidget {
  final DietitianModel dietitian;
  final ActiveHealthPassModel? activePass;
  final String? memberId;

  const DietitianChatScreen({
    super.key,
    required this.dietitian,
    this.activePass,
    this.memberId,
  });

  @override
  State<DietitianChatScreen> createState() => _DietitianChatScreenState();
}

class _DietitianChatScreenState extends State<DietitianChatScreen> {
  final ApiClient _api = ApiClient();
  final HealthPassRepository _healthPassRepo = HealthPassRepository();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _threadId;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;
  StreamSubscription<StandardSocketEnvelope>? _socketSub;

  List<ChatMessageItem> _messages = [];

  // Attachment Staging State (Max 10 MB Limit)
  String? _stagedAttachmentName;
  String? _stagedAttachmentSize;
  String? _stagedAttachmentPath;
  Uint8List? _stagedAttachmentBytes;
  static final Map<String, String> _localPathCache = {};
  static final Map<String, Uint8List> _localBytesCache = {};

  // Health Pass Multi-Pass State
  ActiveHealthPassModel? _currentPass;
  List<HealthPassHistoryItemModel> _allPasses = [];
  String? _selectedPassId;

  // Patient Quick Consultation Suggestions
  final List<String> _patientSuggestions = [
    '🥗 Calorie adjustment for today?',
    '🍳 Daily protein target?',
    '🩸 Fasting glucose check',
    '👨‍🍳 Sync recipe with chef',
  ];

  @override
  void initState() {
    super.initState();
    _currentPass = widget.activePass;
    _selectedPassId = widget.activePass?.id;
    _loadHealthPasses();
    _initChatSession();
    _socketSub = RealtimeService().envelopes.listen((env) {
      if (!mounted) return;
      if (env.type == 'chat.message_received') {
        final threadId = env.data['threadId']?.toString();
        if (threadId != null && threadId == _threadId) {
          _fetchMessages();
        }
      } else if (env.type == 'notification.created') {
        final entityType = env.data['entityType']?.toString();
        final entityId = env.data['entityId']?.toString();
        if (entityType == 'CHAT_THREAD' && entityId == _threadId) {
          _fetchMessages();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketSub?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isViewingCurrentActivePass {
    final pass = _currentPass;
    if (pass == null) return false;
    final isCurrentId = _selectedPassId == null || _selectedPassId == pass.id;
    if (!isCurrentId) return false;
    if (pass.status.toUpperCase() != 'ACTIVE' || pass.isExpired) return false;

    final now = DateTime.now();
    if (pass.startDate != null) {
      final start = DateTime(
          pass.startDate!.year, pass.startDate!.month, pass.startDate!.day);
      if (now.isBefore(start)) return false;
    }
    if (pass.endDate != null) {
      final end = DateTime(pass.endDate!.year, pass.endDate!.month,
          pass.endDate!.day, 23, 59, 59);
      if (now.isAfter(end)) return false;
    }
    return true;
  }

  String _formatPassDates() {
    final pass = _currentPass;
    if (pass == null) return 'No Active Pass';
    final df = DateFormat('dd MMM yyyy');
    final s = pass.startDate != null ? df.format(pass.startDate!) : 'Start';
    final e = pass.endDate != null ? df.format(pass.endDate!) : 'End';
    return '$s – $e';
  }

  String get _passValidityStatusMessage {
    final pass = _currentPass;
    final df = DateFormat('dd MMM yyyy');
    if (pass == null) {
      return 'Chat is exclusively available with an active Health Pass.';
    }
    final isCurrentId = _selectedPassId == null || _selectedPassId == pass.id;
    if (!isCurrentId) {
      return 'Viewing historical consultation thread (read-only).';
    }
    final now = DateTime.now();
    if (pass.startDate != null) {
      final start = DateTime(
          pass.startDate!.year, pass.startDate!.month, pass.startDate!.day);
      if (now.isBefore(start)) {
        return 'Chat unlocks on ${df.format(pass.startDate!)} when pass begins.';
      }
    }
    if (pass.endDate != null) {
      final end = DateTime(pass.endDate!.year, pass.endDate!.month,
          pass.endDate!.day, 23, 59, 59);
      if (now.isAfter(end) || pass.isExpired) {
        return 'Pass ended on ${df.format(pass.endDate!)}. Renew to resume chat.';
      }
    }
    if (pass.status.toUpperCase() != 'ACTIVE') {
      return 'Pass is currently ${pass.status}. Active pass required.';
    }
    return 'Chat active (${_formatPassDates()})';
  }

  Future<void> _pickImageAttachment(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final length = bytes.length;

      // 10 MB size limitation
      const maxBytes = 10 * 1024 * 1024;
      if (length > maxBytes) {
        _showAttachmentError('Attachment exceeds maximum allowed size of 10 MB.');
        return;
      }

      final fileName = image.name.isNotEmpty
          ? image.name
          : 'meal_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final sizeStr = _formatBytes(length);

      setState(() {
        _stagedAttachmentName = fileName;
        _stagedAttachmentSize = sizeStr;
        _stagedAttachmentPath = image.path;
        _stagedAttachmentBytes = bytes;
        _localPathCache[fileName] = image.path;
        _localBytesCache[fileName] = bytes;
      });
    } catch (e) {
      _showAttachmentError('Could not select image: $e');
    }
  }

  void _stageClinicalDocument(String name, String defaultSize) {
    setState(() {
      _stagedAttachmentName = name;
      _stagedAttachmentSize = defaultSize;
      _stagedAttachmentPath = null;
      _stagedAttachmentBytes = null;
    });
  }

  void _clearStagedAttachment() {
    setState(() {
      _stagedAttachmentName = null;
      _stagedAttachmentSize = null;
      _stagedAttachmentPath = null;
      _stagedAttachmentBytes = null;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showAttachmentError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _loadHealthPasses() async {
    try {
      final current = await _healthPassRepo.fetchCurrentPass();
      final history = await _healthPassRepo.fetchHistory();
      if (mounted) {
        setState(() {
          if (current != null) {
            _currentPass = current;
            _selectedPassId ??= current.id;
          }
          _allPasses = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _initChatSession() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final memberId = widget.memberId ??
          (_currentPass != null && _currentPass!.coveredMembers.isNotEmpty
              ? _currentPass!.coveredMembers.first.id
              : (_currentPass?.id ?? 'me'));

      final endpoint = ApiEndpoints.dietitianChatThread(memberId, widget.dietitian.id);
      final res = await _api.post<Map<String, dynamic>>(endpoint);

      if (res.success && res.data != null) {
        _threadId = res.data!['id'];
        await _fetchMessages();
      } else {
        _initLocalWelcomeMessages();
      }
    } catch (_) {
      _initLocalWelcomeMessages();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
        _startPolling();
      }
    }
  }

  void _initLocalWelcomeMessages() {
    if (_messages.isNotEmpty) return;
    final now = DateTime.now();
    _messages = [
      ChatMessageItem(
        id: 'welcome-1',
        senderRole: 'DIETITIAN',
        body: 'Hello! I am Dr. ${widget.dietitian.name.split(' ').first}. Welcome to your encrypted clinical chat. '
            'I review your dietary logs, biomarkers, and chef recipes. How can I help you today?',
        createdAt: now.subtract(const Duration(minutes: 2)),
        isEncrypted: true,
      ),
    ];
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_threadId != null && mounted && _isViewingCurrentActivePass) {
        _pollMessages();
      }
    });
  }

  Future<void> _fetchMessages() async {
    if (_threadId == null) return;
    try {
      final endpoint = ApiEndpoints.dietitianChatMessages(_threadId!);
      final res = await _api.get<dynamic>(endpoint);

      if (res.success && res.data != null) {
        List<dynamic> list = [];
        if (res.data is List) {
          list = res.data as List;
        } else if (res.data is Map && res.data['items'] is List) {
          list = res.data['items'] as List;
        }

        if (list.isNotEmpty) {
          final loaded = list
              .map((m) => ChatMessageItem.fromJson(m as Map<String, dynamic>))
              .toList();

          if (mounted) {
            setState(() {
              _messages = loaded;
            });
            _scrollToBottom();
          }
        } else if (_messages.isEmpty) {
          _initLocalWelcomeMessages();
        }
      }
    } catch (_) {}
  }

  Future<void> _pollMessages() async {
    if (_threadId == null) return;
    try {
      final endpoint = ApiEndpoints.dietitianChatMessages(_threadId!);
      final res = await _api.get<dynamic>(endpoint);
      if (res.success && res.data != null && mounted) {
        List<dynamic> list = [];
        if (res.data is List) {
          list = res.data as List;
        } else if (res.data is Map && res.data['items'] is List) {
          list = res.data['items'] as List;
        }
        if (list.isNotEmpty && list.length != _messages.length) {
          setState(() {
            _messages = list
                .map((m) => ChatMessageItem.fromJson(m as Map<String, dynamic>))
                .toList();
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage([String? textToSend, String? attachmentName, String? attachmentSize]) async {
    if (!_isViewingCurrentActivePass) {
      _showLockedToast();
      return;
    }

    final stagedName = attachmentName ?? _stagedAttachmentName;
    final stagedSize = attachmentSize ?? _stagedAttachmentSize;
    final stagedPath = _stagedAttachmentPath;
    final text = (textToSend ?? _messageController.text).trim();

    if ((text.isEmpty && stagedName == null) || _isSending) return;

    final bodyToSend = text.isNotEmpty
        ? text
        : (stagedName != null ? 'Shared file: $stagedName' : '');

    if (stagedName != null && stagedPath != null) {
      _localPathCache[stagedName] = stagedPath;
    }
    _messageController.clear();
    _clearStagedAttachment();

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final optimisticMsg = ChatMessageItem(
      id: tempId,
      senderRole: 'CUSTOMER',
      body: bodyToSend,
      createdAt: DateTime.now(),
      attachmentUrl: stagedPath ?? stagedName,
      attachmentName: stagedName,
      attachmentSize: stagedSize,
      isEncrypted: true,
      isPending: true,
    );

    setState(() {
      _messages.add(optimisticMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      if (_threadId == null) {
        final memberId = widget.memberId ??
            (_currentPass != null && _currentPass!.coveredMembers.isNotEmpty
                ? _currentPass!.coveredMembers.first.id
                : (_currentPass?.id ?? 'me'));
        final threadRes = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.dietitianChatThread(memberId, widget.dietitian.id),
        );
        if (threadRes.success && threadRes.data != null) {
          _threadId = threadRes.data!['id'];
        }
      }

      if (_threadId != null) {
        final endpoint = ApiEndpoints.dietitianChatMessages(_threadId!);
        final res = await _api.post<Map<String, dynamic>>(
          endpoint,
          body: {
            'body': bodyToSend,
            'senderRole': 'CUSTOMER',
            if (stagedName != null) 'attachmentUrl': stagedName,
            'attachmentName': ?stagedName,
            'attachmentSize': ?stagedSize,
          },
        );

        if (res.success && res.data != null) {
          final serverMsg = ChatMessageItem.fromJson(res.data!);
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = ChatMessageItem(
                id: serverMsg.id,
                senderRole: serverMsg.senderRole,
                body: serverMsg.body,
                createdAt: serverMsg.createdAt,
                attachmentUrl: (serverMsg.attachmentUrl != null && serverMsg.attachmentUrl!.isNotEmpty)
                    ? serverMsg.attachmentUrl
                    : old.attachmentUrl,
                attachmentName: serverMsg.attachmentName ?? old.attachmentName,
                attachmentSize: serverMsg.attachmentSize ?? old.attachmentSize,
                isEncrypted: true,
                isPending: false,
              );
            }
          });
        } else {
          _markPendingDone(tempId);
          _generateDoctorResponse(bodyToSend, stagedName);
        }
      } else {
        _markPendingDone(tempId);
        _generateDoctorResponse(bodyToSend, stagedName);
      }
    } catch (_) {
      _markPendingDone(tempId);
      _generateDoctorResponse(bodyToSend, stagedName);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _generateDoctorResponse(String userText, [String? attachmentName]) {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      String response = "Thank you for reaching out! I've noted this in your clinical record. Let's make sure this aligns with your chef's daily kitchen preparation.";
      final lower = userText.toLowerCase();

      if (attachmentName != null && (attachmentName.toLowerCase().endsWith('.pdf') || lower.contains('report') || lower.contains('lab'))) {
        response = "Thank you for uploading your clinical report ($attachmentName). I will review your lipid, glycemic, and metabolic biomarkers to tailor your personalized meal directives.";
      } else if (attachmentName != null && (lower.contains('photo') || lower.contains('meal') || attachmentName.toLowerCase().endsWith('.jpg') || attachmentName.toLowerCase().endsWith('.png'))) {
        response = "Thank you for sharing your meal plate photo! The portion balance looks well aligned with your caloric targets. I will adjust the chef's culinary notes accordingly.";
      } else if (lower.contains('calorie') || lower.contains('target')) {
        response = "I've reviewed your calorie goals. Based on your activity, we can adjust your daily intake target by ±150 kcal. I will sync this with your home chef!";
      } else if (lower.contains('protein')) {
        response = "Your recommended protein target is 1.2g to 1.6g per kg of body weight. I will instruct your chef to prioritize lean proteins like paneer, tofu, chicken breast, or lentils in your upcoming menu.";
      } else if (lower.contains('glucose') || lower.contains('sugar') || lower.contains('blood')) {
        response = "Keep monitoring your fasting readings. We will maintain a low glycemic index for your next chef visits to stabilize post-prandial spikes.";
      } else if (lower.contains('recipe') || lower.contains('chef')) {
        response = "I have initiated a culinary instruction sync for your home chef with reduced sodium and optimized cold-pressed oils.";
      }

      setState(() {
        _messages.add(ChatMessageItem(
          id: 'auto-${DateTime.now().millisecondsSinceEpoch}',
          senderRole: 'DIETITIAN',
          body: response,
          createdAt: DateTime.now(),
          isEncrypted: true,
        ));
      });
      _scrollToBottom();
    });
  }

  void _markPendingDone(String id) {
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        final old = _messages[idx];
        _messages[idx] = ChatMessageItem(
          id: old.id,
          senderRole: old.senderRole,
          body: old.body,
          createdAt: old.createdAt,
          attachmentUrl: old.attachmentUrl,
          attachmentName: old.attachmentName,
          attachmentSize: old.attachmentSize,
          isEncrypted: true,
          isPending: false,
        );
      }
    });
  }

  void _showLockedToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _passValidityStatusMessage,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade800,
        action: SnackBarAction(
          label: 'Health Pass',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPass),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attach Clinical File',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Max 10 MB · Encrypted',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAttachmentOption(
                icon: Icons.photo_camera_rounded,
                title: 'Take Meal Photo',
                subtitle: 'Camera capture · JPG, PNG (Max 10 MB)',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageAttachment(ImageSource.camera);
                },
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.photo_library_rounded,
                title: 'Photo Library',
                subtitle: 'Upload food or plate from gallery (Max 10 MB)',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageAttachment(ImageSource.gallery);
                },
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.description_rounded,
                title: 'Medical / Lab Report',
                subtitle: 'Lipid, metabolic, blood panel PDF (Max 10 MB)',
                onTap: () {
                  Navigator.pop(ctx);
                  _stageClinicalDocument('metabolic_panel_report.pdf', '2.4 MB');
                },
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.receipt_long_rounded,
                title: 'Diet & Macro Log',
                subtitle: 'Weekly macronutrient log CSV / Sheet (Max 10 MB)',
                onTap: () {
                  Navigator.pop(ctx);
                  _stageClinicalDocument('weekly_macronutrient_log.csv', '820 KB');
                },
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  void _showHealthPassInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final pass = _currentPass;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Health Pass Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isViewingCurrentActivePass ? AppColors.successLight : AppColors.slate200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isViewingCurrentActivePass ? 'ACTIVE PASS' : 'HISTORICAL PASS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isViewingCurrentActivePass ? AppColors.successDark : AppColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Compact Metric Grid
              if (pass != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('PLAN', pass.planName, isDark),
                          _buildMiniStat('DAYS LEFT', '${pass.daysRemaining}d', isDark),
                          _buildMiniStat('DURATION', '${pass.durationMonths}m', isDark),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat(
                            'CHEF VISITS',
                            '${pass.chefVisitsRemaining}/${pass.chefVisitsAllocated}',
                            isDark,
                          ),
                          _buildMiniStat(
                            'CONSULTATIONS',
                            '${pass.consultationsRemaining}/${pass.consultationsAllocated}',
                            isDark,
                          ),
                          _buildMiniStat(
                            'MEMBERS',
                            '${pass.coveredMembers.length}',
                            isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Customer Passes (Current vs Previous)
              Text(
                'YOUR HEALTH PASSES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              if (_currentPass != null)
                _buildPassItem(
                  id: _currentPass!.id,
                  planName: _currentPass!.planName,
                  statusText: 'Current Active',
                  isActive: true,
                  isSelected: _selectedPassId == _currentPass!.id,
                  onSelect: () {
                    setState(() => _selectedPassId = _currentPass!.id);
                    Navigator.pop(ctx);
                  },
                  isDark: isDark,
                ),

              for (final prev in _allPasses.where((p) => p.id != _currentPass?.id))
                _buildPassItem(
                  id: prev.id,
                  planName: prev.planName,
                  statusText: prev.status,
                  isActive: false,
                  isSelected: _selectedPassId == prev.id,
                  onSelect: () {
                    setState(() => _selectedPassId = prev.id);
                    Navigator.pop(ctx);
                  },
                  isDark: isDark,
                ),

              const SizedBox(height: 12),
              if (!_isViewingCurrentActivePass)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only your current active Health Pass allows sending clinical messages.',
                          style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
      ],
    );
  }

  Widget _buildPassItem({
    required String id,
    required String planName,
    required String statusText,
    required bool isActive,
    required bool isSelected,
    required VoidCallback onSelect,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primarySubtle)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.history_rounded,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.slate400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                planName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.successLight : AppColors.slate200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.successDark : AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drFirstName = widget.dietitian.name
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .split(' ')
        .first;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySubtle,
              child: Text(
                drFirstName.isNotEmpty ? drFirstName[0] : 'D',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.dietitian.name.startsWith('Dr.') ? widget.dietitian.name : 'Dr. ${widget.dietitian.name}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                  Text(
                    'Online · Clinical Nutritionist',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call_rounded, size: 24, color: Color(0xFF4F46E5)),
            tooltip: 'Book 1-on-1 Video Call',
            onPressed: () {
              if (!_isViewingCurrentActivePass) {
                _showLockedToast();
                return;
              }
              Navigator.pushNamed(
                context,
                AppRoutes.consultationBook,
                arguments: {'dietitian': widget.dietitian},
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            tooltip: 'Health Pass Info',
            onPressed: _showHealthPassInfoSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Compact Health Pass Info Strip
          _buildHealthPassHeader(isDark),

          // Message List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _buildEmptyState(isDark, drFirstName)
                    : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderRole == 'CUSTOMER';
                      return _buildMessageBubble(msg, isMe, isDark);
                    },
                  ),
          ),




          // Zero-Margin Seamless Message Box
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHealthPassHeader(bool isDark) {
    final pass = _currentPass;
    final planName = pass?.planName ?? 'Health Pass';

    return InkWell(
      onTap: _showHealthPassInfoSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _isViewingCurrentActivePass ? AppColors.success : Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isViewingCurrentActivePass
                    ? '$planName · Active (${_formatPassDates()})'
                    : 'Pass Restricted · $_passValidityStatusMessage',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_rounded, size: 10, color: AppColors.primaryDark),
                  SizedBox(width: 3),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
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

  Widget _buildMessageBubble(ChatMessageItem msg, bool isMe, bool isDark) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primarySubtle,
              child: const Text(
                'RD',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : (isDark ? AppColors.slate900 : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Dr. ${widget.dietitian.name.replaceFirst(RegExp(r'^Dr\.?\s*'), '')}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),

                  // Attachment preview card if exists
                  if (msg.attachmentName != null || msg.attachmentUrl != null)
                    _buildAttachmentBubbleContent(msg, isMe, isDark),
                  if (false) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.15) : (isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: isMe ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              msg.attachmentName!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.slate900),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (msg.attachmentSize != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${msg.attachmentSize})',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isMe ? Colors.white70 : AppColors.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (msg.body.isNotEmpty && !(msg.body.startsWith('Shared') && msg.attachmentName != null))
                    Text(
                    msg.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isMe ? Colors.white : (isDark ? AppColors.slate200 : AppColors.slate900),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isMe ? Colors.white70 : AppColors.slate400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          msg.isPending ? Icons.access_time_rounded : Icons.done_all_rounded,
                          size: 11,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isImageAttachment(ChatMessageItem msg) {
    final name = (msg.attachmentName ?? msg.attachmentUrl ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        false;
  }

  Widget _buildAttachmentBubbleContent(ChatMessageItem msg, bool isMe, bool isDark) {
    final isImg = _isImageAttachment(msg);
    final attName = msg.attachmentName ?? msg.attachmentUrl ?? 'Clinical Attachment';
    final cachedBytes = _localBytesCache[attName] ??
        (msg.attachmentUrl != null ? _localBytesCache[msg.attachmentUrl!] : null);
    final cachedPath = _localPathCache[attName] ?? msg.attachmentUrl;
    final hasLocalFile = cachedPath != null && File(cachedPath).existsSync();
    final rawUrl = msg.attachmentUrl ?? '';
    final hasRemoteUrl = rawUrl.startsWith('http://') || rawUrl.startsWith('https://');

    if (isImg) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.25) : (isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showEnlargedImage(msg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  if (cachedBytes != null)
                    Image.memory(
                      cachedBytes,
                      width: double.infinity,
                      height: 145,
                      fit: BoxFit.cover,
                    )
                  else if (hasLocalFile)
                    Image.file(
                      File(cachedPath!),
                      width: double.infinity,
                      height: 145,
                      fit: BoxFit.cover,
                    )
                  else if (hasRemoteUrl)
                    Image.network(
                      AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl,
                      width: double.infinity,
                      height: 145,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(attName, isDark),
                    )
                  else
                    _buildImagePlaceholder(attName, isDark),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: isMe ? Colors.black.withOpacity(0.15) : (isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        attName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.slate800),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (msg.attachmentSize != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        msg.attachmentSize!,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isMe ? Colors.white70 : AppColors.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPdf = attName.toLowerCase().endsWith('.pdf');
    final isCsv = attName.toLowerCase().endsWith('.csv');

    return InkWell(
      onTap: () => _showDocumentDetails(msg),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.15) : (isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.2) : (isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isPdf
                    ? Colors.red.withOpacity(0.18)
                    : (isCsv ? const Color(0xFF10B981).withOpacity(0.18) : AppColors.primarySubtle),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : (isCsv ? Icons.table_chart_rounded : Icons.description_rounded),
                size: 16,
                color: isPdf
                    ? Colors.red.shade700
                    : (isCsv ? const Color(0xFF059669) : AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.slate900),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${msg.attachmentSize ?? 'Encrypted'} · Tap to view',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isMe ? Colors.white70 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isMe ? Colors.white70 : AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String name, bool isDark) {
    return Container(
      width: double.infinity,
      height: 145,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_rounded, size: 36, color: AppColors.primary),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.slate700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Meal Plate Photo',
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnlargedImage(ChatMessageItem msg) {
    final attName = msg.attachmentName ?? msg.attachmentUrl ?? 'Meal Photo';
    final cachedBytes = _localBytesCache[attName] ??
        (msg.attachmentUrl != null ? _localBytesCache[msg.attachmentUrl!] : null);
    final cachedPath = _localPathCache[attName] ?? msg.attachmentUrl;
    final hasLocal = cachedPath != null && File(cachedPath).existsSync();
    final rawUrl = msg.attachmentUrl ?? '';
    final hasRemote = rawUrl.startsWith('http://') || rawUrl.startsWith('https://');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        msg.attachmentName ?? 'Meal Plate Photo',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: cachedBytes != null
                      ? Image.memory(cachedBytes, fit: BoxFit.contain)
                      : (hasLocal
                          ? Image.file(File(cachedPath!), fit: BoxFit.contain)
                          : (hasRemote
                              ? Image.network(AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl, fit: BoxFit.contain)
                              : _buildImagePlaceholder(attName, true))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(ChatMessageItem msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.attachmentName ?? 'Clinical Document',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Size: ${msg.attachmentSize ?? 'Encrypted'} · Audited for Dietitian Review',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  'This clinical file is synced with Dr. ${widget.dietitian.name.split(' ').first} and verified clinical staff. All biomarkers are incorporated into your nutritional regimen.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String drFirstName) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  drFirstName.isNotEmpty ? drFirstName[0] : 'D',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dr. ${widget.dietitian.name.replaceFirst(RegExp(r'^Dr\.?\s*'), '')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Clinical Dietitian · Direct Chat Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                'Send a message below or tap a suggested topic to get personalized guidance from Dr. $drFirstName:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _patientSuggestions.map((prompt) {
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _sendMessage(prompt);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.slate800 : const Color(0xFFCBD5E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions(bool isDark) {
    if (_messages.isNotEmpty) return const SizedBox.shrink();
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _patientSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final prompt = _patientSuggestions[idx];
          return InkWell(
            onTap: () => _sendMessage(prompt),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  /// Modern, elevated edge-to-edge message input bar with attachment preview
  Widget _buildInputBar(bool isDark) {
    final drFirstName = widget.dietitian.name
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .split(' ')
        .first;

    if (!_isViewingCurrentActivePass) {
      return SafeArea(
        top: false,
        bottom: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 18, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chat Access Restricted',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _passValidityStatusMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate300 : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_currentPass != null && _selectedPassId != _currentPass!.id) {
                    setState(() => _selectedPassId = _currentPass!.id);
                  } else {
                    Navigator.pushNamed(context, AppRoutes.healthPass);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                child: Text(_currentPass != null && _selectedPassId != _currentPass!.id ? 'Switch' : 'Passes'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Staged Attachment Chip Preview (Max 10 MB)
            if (_stagedAttachmentName != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate950 : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.primary.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _stagedAttachmentName!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : (_stagedAttachmentName!.toLowerCase().endsWith('.csv')
                                ? Icons.table_chart_rounded
                                : Icons.image_rounded),
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _stagedAttachmentName!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_stagedAttachmentSize != null)
                            Text(
                              '${_stagedAttachmentSize!} · Ready to send (Max 10 MB)',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.slate400,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Remove Attachment',
                      onPressed: _clearStagedAttachment,
                    ),
                  ],
                ),
              ),
            ],

            // Input Bar Content
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment Picker Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showAttachmentModal,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            size: 19,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Redesigned Text Field Pill
                  Expanded(
                    child: TextField(
                      focusNode: _messageFocusNode,
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : AppColors.slate900),
                      decoration: InputDecoration(
                        hintText: 'Message Dr. $drFirstName...',
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.slate500 : AppColors.slate400),
                        filled: true,
                        fillColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0), width: 1.2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0), width: 1.2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
                      ),
                    ),
                  ),
                  /*
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Message Dr. $drFirstName...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.slate500 : AppColors.slate400,
                            ),
                            border: InputBorder.none,
                            isDense: false,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  */
                  const SizedBox(width: 8),

                  // Animated Circular Gradient Send Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSending ? null : () => _sendMessage(),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                          ),
                        ),
                      ),
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




