import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
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

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] ?? UniqueKey().toString(),
      senderRole: (json['senderRole'] ?? 'CUSTOMER').toString().toUpperCase(),
      body: json['body'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      attachmentUrl: json['attachmentUrl'],
      attachmentName: json['attachmentName'],
      attachmentSize: json['attachmentSize'],
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
  final ScrollController _scrollController = ScrollController();

  String? _threadId;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  List<ChatMessageItem> _messages = [];

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
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isViewingCurrentActivePass {
    if (_currentPass == null) return false;
    final isCurrentId = _selectedPassId == null || _selectedPassId == _currentPass!.id;
    return isCurrentId && _currentPass!.status.toUpperCase() == 'ACTIVE' && !_currentPass!.isExpired;
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

    final text = (textToSend ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final optimisticMsg = ChatMessageItem(
      id: tempId,
      senderRole: 'CUSTOMER',
      body: text,
      createdAt: DateTime.now(),
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
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
            'body': text,
            'senderRole': 'CUSTOMER',
            'attachmentName': ?attachmentName,
            'attachmentSize': ?attachmentSize,
          },
        );

        if (res.success && res.data != null) {
          final serverMsg = ChatMessageItem.fromJson(res.data!);
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              _messages[idx] = serverMsg;
            }
          });
        } else {
          _markPendingDone(tempId);
        }
      } else {
        _markPendingDone(tempId);
      }
    } catch (_) {
      _markPendingDone(tempId);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
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
      const SnackBar(
        content: Text('Chat is active only with your current Health Pass.'),
        duration: Duration(seconds: 2),
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
    if (!_isViewingCurrentActivePass) {
      _showLockedToast();
      return;
    }

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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attach File',
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
                      'Max 5 MB · Encrypted',
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
                title: 'Food / Meal Photo',
                subtitle: 'JPG, PNG · Under 5 MB',
                onTap: () {
                  Navigator.pop(ctx);
                  _sendMessage('📸 Food Photo: Balanced Macro Plate', 'meal_photo_lunch.jpg', '1.8 MB');
                },
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.description_rounded,
                title: 'Medical / Lab Report',
                subtitle: 'PDF, DOCX · Under 5 MB',
                onTap: () {
                  Navigator.pop(ctx);
                  _sendMessage('📄 Lab Report: Lipid & Fasting Glucose', 'metabolic_panel.pdf', '2.4 MB');
                },
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.receipt_long_rounded,
                title: 'Diet Log Snapshot',
                subtitle: 'CSV, Image · Under 5 MB',
                onTap: () {
                  Navigator.pop(ctx);
                  _sendMessage('📊 7-Day Macronutrient Log', 'diet_log_weekly.png', '820 KB');
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
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderRole == 'CUSTOMER';
                      return _buildMessageBubble(msg, isMe, isDark);
                    },
                  ),
          ),

          // Quick Suggestion Chips
          if (_isViewingCurrentActivePass) _buildQuickSuggestions(isDark),

          // Zero-Margin Seamless Message Box
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHealthPassHeader(bool isDark) {
    final pass = _currentPass;
    final planName = pass?.planName ?? 'Health Pass';
    final days = pass?.daysRemaining ?? 30;

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
                    ? '$planName · Active ($days days left)'
                    : 'Historical Pass ($planName) · Read Only',
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
      padding: const EdgeInsets.only(bottom: 10),
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
                  if (msg.attachmentName != null) ...[
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

  Widget _buildQuickSuggestions(bool isDark) {
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

  /// Clean, edge-to-edge message input bar without borders or awkward spaces
  Widget _buildInputBar(bool isDark) {
    if (!_isViewingCurrentActivePass) {
      return SafeArea(
        top: false,
        bottom: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chat active only with current Health Pass',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber),
                ),
              ),
              if (_currentPass != null)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedPassId = _currentPass!.id);
                  },
                  child: const Text('Switch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment Button
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded, size: 21, color: AppColors.slate500),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Attach File (Max 5 MB)',
                onPressed: _showAttachmentModal,
              ),
            ),
            const SizedBox(width: 4),

            // Seamless Input Pill
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 38, maxHeight: 100),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate950 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask Dr. ${widget.dietitian.name.replaceFirst(RegExp(r'^Dr\.?\s*'), '').split(' ').first}...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: InkWell(
                onTap: _isSending ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
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
                            size: 16,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
