import 'package:flutter/material.dart';
import '../../domain/entities/health_progress_entity.dart';
import '../../data/repositories/health_progress_repository_impl.dart';

class ProgressTimelineScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const ProgressTimelineScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<ProgressTimelineScreen> createState() => _ProgressTimelineScreenState();
}

class _ProgressTimelineScreenState extends State<ProgressTimelineScreen> {
  final HealthProgressRepositoryImpl _repository = HealthProgressRepositoryImpl();
  List<TimelineItemEntity> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.getTimeline(widget.memberId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  IconData _resolveIcon(String iconKey) {
    switch (iconKey.toLowerCase()) {
      case 'scale':
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'water':
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'restaurant':
      case 'meal':
        return Icons.restaurant_outlined;
      case 'fitness':
      case 'steps':
      case 'directions_walk':
        return Icons.directions_walk_outlined;
      case 'bed':
      case 'sleep':
      case 'nights_stay':
        return Icons.bedtime_outlined;
      case 'assignment':
      case 'diet_plan':
      case 'calendar':
        return Icons.assignment_outlined;
      case 'medical_services':
      case 'consultation':
        return Icons.medical_services_outlined;
      default:
        return Icons.timeline_outlined;
    }
  }

  Color _resolveColor(String iconKey) {
    switch (iconKey.toLowerCase()) {
      case 'scale':
      case 'weight':
        return const Color(0xFF10B981); // Emerald
      case 'water':
      case 'water_drop':
        return const Color(0xFF0EA5E9); // Sky
      case 'restaurant':
      case 'meal':
        return const Color(0xFFF59E0B); // Amber
      case 'fitness':
      case 'steps':
      case 'directions_walk':
        return const Color(0xFF6366F1); // Indigo
      case 'bed':
      case 'sleep':
      case 'nights_stay':
        return const Color(0xFF8B5CF6); // Purple
      case 'assignment':
      case 'diet_plan':
        return const Color(0xFF059669); // Forest
      case 'medical_services':
      case 'consultation':
        return const Color(0xFFEC4899); // Rose
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.memberName,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchTimeline,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTimeline,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Could not load timeline',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchTimeline,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_toggle_off_rounded, size: 36, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Milestones Yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you log weight, water, confirm meals, or attend consultations, your milestones will appear here in chronological order.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Group items by date header
    final Map<String, List<TimelineItemEntity>> grouped = {};
    for (final item in _items) {
      final header = _formatDateHeader(item.timestamp);
      grouped.putIfAbsent(header, () => []).add(item);
    }

    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: dateKeys.length,
      itemBuilder: (context, dateIndex) {
        final dateHeader = dateKeys[dateIndex];
        final dayItems = grouped[dateHeader]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateHeader,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...dayItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == dayItems.length - 1 && dateIndex == dateKeys.length - 1;

              return _buildTimelineRow(item, isLast);
            }),
          ],
        );
      },
    );
  }

  Widget _buildTimelineRow(TimelineItemEntity item, bool isLast) {
    final color = _resolveColor(item.icon);
    final iconData = _resolveIcon(item.icon);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator line + badge
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(iconData, size: 18, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
