import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/available_chef_model.dart';
import '../../shared/widgets/ebic_avatar.dart';

/// What the customer chose: a specific chef, or [chef] == null for
/// "let EBIC assign the best available chef".
class ChefChoice {
  final AvailableChefModel? chef;
  const ChefChoice.auto() : chef = null;
  const ChefChoice.chef(AvailableChefModel this.chef);
  bool get isAuto => chef == null;
}

/// "Choose your chef" — lists chefs who can take this exact visit right now
/// (the backend applies the same hub, shift, workload, distance and
/// availability rules it dispatches with), best match first, and own-hub
/// chefs who are currently unavailable with a plain-language reason.
class ChooseChefScreen extends StatefulWidget {
  final String addressId;
  final String? quoteId;
  final int? cookMinutes;
  final String? selectedChefId;

  const ChooseChefScreen({
    super.key,
    required this.addressId,
    this.quoteId,
    this.cookMinutes,
    this.selectedChefId,
  });

  @override
  State<ChooseChefScreen> createState() => _ChooseChefScreenState();
}

class _ChooseChefScreenState extends State<ChooseChefScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String? _error;
  AvailableChefsResult? _result;
  String? _selectedId; // null = auto-assign

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedChefId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.chefBookingsAvailableChefs,
        queryParameters: {
          'addressId': widget.addressId,
          if (widget.quoteId != null) 'quoteId': widget.quoteId!,
          if (widget.cookMinutes != null) 'cookMinutes': widget.cookMinutes.toString(),
        },
      );
      if (!mounted) return;
      if (res.success && res.data != null) {
        final result = AvailableChefsResult.fromJson(res.data!);
        setState(() {
          _result = result;
          // A previously picked chef who is no longer free can't stay selected.
          if (_selectedId != null &&
              !result.availableChefs.any((c) => c.id == _selectedId)) {
            _selectedId = null;
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = res.error?.message ?? res.message ?? 'Could not load chefs right now.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load chefs right now.';
        _loading = false;
      });
    }
  }

  AvailableChefModel? get _selectedChef {
    if (_selectedId == null) return null;
    for (final c in _result?.availableChefs ?? const <AvailableChefModel>[]) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  void _confirm() {
    final chef = _selectedChef;
    Navigator.pop(context, chef == null ? const ChefChoice.auto() : ChefChoice.chef(chef));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        title: const Text(
          'Choose your chef',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh availability',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _result == null ? null : _buildConfirmBar(),
    );
  }

  Widget _buildBody() {
    if (_loading && _result == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text('Checking which chefs can reach you…',
                style: TextStyle(fontSize: 13, color: AppColors.slate500)),
          ],
        ),
      );
    }
    if (_error != null && _result == null) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Couldn’t load chefs',
        body: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    final result = _result!;
    final available = result.availableChefs;
    final unavailable = result.unavailableChefs;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HubStrip(result: result),
          const SizedBox(height: 14),
          _AutoAssignTile(
            selected: _selectedId == null,
            recommended: available.isNotEmpty ? available.first : null,
            onTap: () => setState(() => _selectedId = null),
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Available now',
            count: available.length,
            subtitle: 'Can reach your kitchen within ${result.maxTravelTimeMin} min',
          ),
          const SizedBox(height: 8),
          if (available.isEmpty)
            _NoneAvailableCard(hubOpen: result.hubOpen)
          else
            ...available.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChefCard(
                  chef: c,
                  selected: _selectedId == c.id,
                  onTap: () => setState(() => _selectedId = c.id),
                  onViewProfile: () => _showProfile(c),
                ),
              ),
            ),
          if (unavailable.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionHeader(
              title: 'Unavailable right now',
              count: unavailable.length,
              subtitle: 'From your hub — check back later',
            ),
            const SizedBox(height: 8),
            ...unavailable.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChefCard(chef: c, selected: false, onViewProfile: () => _showProfile(c)),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const _HowItWorksNote(),
        ],
      ),
    );
  }

  Widget _buildConfirmBar() {
    final chef = _selectedChef;
    final label = chef == null ? 'Continue with auto-assign' : 'Continue with ${chef.name}';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2)),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfile(AvailableChefModel chef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChefProfileSheet(
        chef: chef,
        selected: _selectedId == chef.id,
        onSelect: chef.available
            ? () {
                Navigator.pop(ctx);
                setState(() => _selectedId = chef.id);
              }
            : null,
      ),
    );
  }
}

// ───────────────────────────── Pieces ─────────────────────────────

class _HubStrip extends StatelessWidget {
  final AvailableChefsResult result;
  const _HubStrip({required this.result});

  @override
  Widget build(BuildContext context) {
    final open = result.hubOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.primarySubtle, shape: BoxShape.circle),
            child: const Icon(Icons.store_mall_directory_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.hubName ?? 'Your service hub',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.availableCount} chef${result.availableCount == 1 ? '' : 's'} free for this visit',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: open ? 'Open now' : 'Closed now',
            color: open ? AppColors.successDark : AppColors.amber800,
            background: open ? AppColors.successLight : AppColors.amber100,
          ),
        ],
      ),
    );
  }
}

class _AutoAssignTile extends StatelessWidget {
  final bool selected;
  final AvailableChefModel? recommended;
  final VoidCallback onTap;

  const _AutoAssignTile({required this.selected, required this.recommended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hint = recommended == null
        ? 'We’ll assign the nearest free certified chef after payment.'
        : 'Right now that’s ${recommended!.name}'
            '${recommended!.etaMinutes != null ? ', ~${recommended!.etaMinutes} min away' : ''}.';
    return _SelectableShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Text('Let EBIC pick the best chef',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                    _Pill(label: 'Fastest', color: AppColors.primaryDark, background: AppColors.primarySubtle),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RadioDot(selected: selected),
        ],
      ),
    );
  }
}

class _ChefCard extends StatelessWidget {
  final AvailableChefModel chef;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onViewProfile;

  const _ChefCard({required this.chef, required this.selected, this.onTap, required this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    final dimmed = !chef.available;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            EBICAvatar(name: chef.name, imageUrl: chef.photoUrl, radius: 24),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: chef.available ? AppColors.success : AppColors.slate400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      chef.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                    ),
                  ),
                  if (chef.recommended) ...[
                    const SizedBox(width: 6),
                    const _Pill(label: 'Best match', color: AppColors.amber800, background: AppColors.amber100),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _MetaLine(chef: chef),
              const SizedBox(height: 6),
              if (chef.available)
                _TravelLine(chef: chef)
              else
                _Pill(
                  label: chef.availableAt != null
                      ? '${chef.statusLabel} · free ~${_formatTime(context, chef.availableAt!)}'
                      : chef.statusLabel,
                  color: AppColors.slate700,
                  background: AppColors.slate100,
                  icon: Icons.schedule_rounded,
                ),
              if (chef.cookedForYouCount > 0 || chef.specialities.isNotEmpty || !chef.fromYourHub) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (chef.cookedForYouCount > 0)
                      _Pill(
                        label: 'Cooked for you ${chef.cookedForYouCount}×',
                        color: AppColors.primaryDark,
                        background: AppColors.primarySubtle,
                        icon: Icons.favorite_rounded,
                      ),
                    if (!chef.fromYourHub)
                      _Pill(
                        label: 'From ${chef.hubName}',
                        color: AppColors.secondary,
                        background: const Color(0xFFE0F2FE),
                      ),
                    ...chef.specialities.take(3).map(
                          (s) => _Pill(label: s, color: AppColors.slate700, background: AppColors.slate100),
                        ),
                    if (chef.specialities.length > 3)
                      _Pill(
                        label: '+${chef.specialities.length - 3}',
                        color: AppColors.slate600,
                        background: AppColors.slate100,
                      ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onViewProfile,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  child: const Text('View profile & reviews',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (chef.available) ...[
          const SizedBox(width: 8),
          _RadioDot(selected: selected),
        ],
      ],
    );

    return Opacity(
      opacity: dimmed ? 0.62 : 1,
      child: _SelectableShell(selected: selected, onTap: onTap, child: content),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final AvailableChefModel chef;
  const _MetaLine({required this.chef});

  @override
  Widget build(BuildContext context) {
    final parts = <InlineSpan>[];
    if (chef.rating != null) {
      parts.add(const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
      ));
      parts.add(TextSpan(
        text: ' ${chef.rating!.toStringAsFixed(1)}',
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800),
      ));
      parts.add(TextSpan(text: ' (${chef.ratingCount})'));
    } else {
      parts.add(const TextSpan(
        text: 'New chef',
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate700),
      ));
    }
    if (chef.experienceYears != null && chef.experienceYears! > 0) {
      parts.add(TextSpan(text: '  ·  ${chef.experienceYears} yrs exp'));
    }
    if (chef.completedVisits > 0) {
      parts.add(TextSpan(text: '  ·  ${chef.completedVisits} visits'));
    }
    return Text.rich(
      TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.slate500), children: parts),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TravelLine extends StatelessWidget {
  final AvailableChefModel chef;
  const _TravelLine({required this.chef});

  @override
  Widget build(BuildContext context) {
    final eta = chef.etaMinutes;
    final km = chef.distanceKm;
    if (eta == null && km == null) {
      return const _Pill(
        label: 'Available now',
        color: AppColors.successDark,
        background: AppColors.successLight,
        icon: Icons.check_circle_rounded,
      );
    }
    return Row(
      children: [
        const Icon(Icons.two_wheeler_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            [
              if (eta != null) '~$eta min away',
              if (km != null) '${km.toStringAsFixed(1)} km',
            ].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
          ),
        ),
      ],
    );
  }
}

class _ChefProfileSheet extends StatelessWidget {
  final AvailableChefModel chef;
  final bool selected;
  final VoidCallback? onSelect;

  const _ChefProfileSheet({required this.chef, required this.selected, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  Row(
                    children: [
                      EBICAvatar(name: chef.name, imageUrl: chef.photoUrl, radius: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chef.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                            const SizedBox(height: 2),
                            Text('Certified EBIC chef · ${chef.hubName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                            const SizedBox(height: 6),
                            chef.available
                                ? const _Pill(
                                    label: 'Available now',
                                    color: AppColors.successDark,
                                    background: AppColors.successLight,
                                    icon: Icons.check_circle_rounded)
                                : _Pill(
                                    label: chef.statusLabel,
                                    color: AppColors.slate700,
                                    background: AppColors.slate100,
                                    icon: Icons.schedule_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _Stat(
                        value: chef.rating != null ? chef.rating!.toStringAsFixed(1) : '—',
                        label: chef.ratingCount > 0 ? '${chef.ratingCount} ratings' : 'No ratings yet',
                        icon: Icons.star_rounded,
                        iconColor: AppColors.accent,
                      ),
                      _Stat(
                        value: chef.experienceYears != null ? '${chef.experienceYears}y' : '—',
                        label: 'Experience',
                        icon: Icons.workspace_premium_rounded,
                        iconColor: AppColors.purple500,
                      ),
                      _Stat(
                        value: '${chef.completedVisits}',
                        label: 'Visits done',
                        icon: Icons.restaurant_rounded,
                        iconColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (chef.available && (chef.etaMinutes != null || chef.cookedForYouCount > 0)) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              [
                                if (chef.etaMinutes != null)
                                  'About ${chef.etaMinutes} min from your kitchen'
                                      '${chef.distanceKm != null ? ' (${chef.distanceKm!.toStringAsFixed(1)} km)' : ''}',
                                if (chef.cookedForYouCount > 0)
                                  'Has cooked for you ${chef.cookedForYouCount} time${chef.cookedForYouCount == 1 ? '' : 's'}',
                              ].join('\n'),
                              style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (chef.specialities.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Specialities',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chef.specialities
                          .map((s) => _Pill(label: s, color: AppColors.slate700, background: AppColors.slate100))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('Recent reviews',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                  const SizedBox(height: 8),
                  if (chef.recentReviews.isEmpty)
                    const Text('No written reviews yet.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.slate500))
                  else
                    ...chef.recentReviews.map((r) => _ReviewTile(review: r)),
                ],
              ),
            ),
            if (onSelect != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(selected ? 'Selected' : 'Choose ${chef.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ChefReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(review.comment, style: const TextStyle(fontSize: 12.5, color: AppColors.slate700, height: 1.35)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _Stat({required this.value, required this.label, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String subtitle;

  const _SectionHeader({required this.title, required this.count, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title ($count)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
      ],
    );
  }
}

class _NoneAvailableCard extends StatelessWidget {
  final bool hubOpen;
  const _NoneAvailableCard({required this.hubOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.amber700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hubOpen ? 'No chef is free for this visit right now' : 'Your hub is closed right now',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.amber800),
                ),
                const SizedBox(height: 4),
                Text(
                  hubOpen
                      ? 'Every nearby chef is on another booking or off duty. Pull down to refresh in a few minutes.'
                      : 'Chefs start taking visits when the hub opens. Pull down to refresh later.',
                  style: const TextStyle(fontSize: 12, color: AppColors.amber800, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksNote extends StatelessWidget {
  const _HowItWorksNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: AppColors.slate400),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your chef is confirmed once payment completes. If they’ve just been booked by someone else, '
              'we’ll assign the best available chef instead and show you who’s coming.',
              style: TextStyle(fontSize: 11.5, color: AppColors.slate500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SelectableShell extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  const _SelectableShell({required this.selected, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySubtle : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.slate200,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
      color: selected ? AppColors.primary : AppColors.slate300,
      size: 24,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const _Pill({required this.label, required this.color, required this.background, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);
