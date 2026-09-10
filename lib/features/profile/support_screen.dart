import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  // Section 56 Ticket Categories
  final List<String> _categories = [
    'ORDER',
    'CHEF',
    'PAYMENT',
    'REFUND',
    'CREDIT',
    'CANCELLATION',
    'NO_SHOW',
    'DELAY',
    'REPLACEMENT',
    'HEALTH_PASS',
    'CONSULTATION',
    'DIET_PLAN',
    'DIET_MEAL',
    'PROMOTION',
    'ACCOUNT',
    'ADDRESS',
    'APP',
    'TECHNICAL',
    'OTHER',
  ];

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How does EBIC automatic chef assignment work?',
      'a': 'Customers do not manually select chefs. Once your quote is paid, our backend assignment engine matches the nearest qualified executive chef based on proximity, culinary tier, and live shift capacity.'
    },
    {
      'q': 'What is the dynamic cooking time engine?',
      'a': 'Cooking time is calculated from recipe dependencies, batch overlap, portion count, and plating rules. Times are never hard-coded or multiplied directly.'
    },
    {
      'q': 'How does Health Pass differ from Chef Booking?',
      'a': 'Health Pass is a separate clinical subscription owning dietitians, consultations, diet plans, and health profiles. Chef Booking is an on-demand culinary dispatch service.'
    },
    {
      'q': 'How are ingredients handled?',
      'a': 'Every confirmed booking generates a preparation checklist indicating customer-supplied staples and EBIC-supplied gourmet spices. You can mark items ready or request substitutions.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get<dynamic>(ApiEndpoints.supportTickets);
      if (res.success && res.data != null) {
        final raw = res.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['tickets'] is List) {
          list = raw['tickets'];
        }
        setState(() {
          _tickets = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateTicketDialog() {
    String selectedCategory = _categories.first;
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Raise Support Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Issue Category'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject', hintText: 'Brief summary of issue'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details / Description',
                    hintText: 'Describe your query or problem in detail...',
                  ),
                ),
                const SizedBox(height: 20),

                EbicButton(
                  label: 'Submit Ticket',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) return;
                    setSheetState(() => isSubmitting = true);

                    try {
                      await _api.post<Map<String, dynamic>>(
                        ApiEndpoints.supportTickets,
                        body: {
                          'category': selectedCategory,
                          'subject': subjectCtrl.text.trim(),
                          'message': messageCtrl.text.trim(),
                        },
                      );
                      Navigator.pop(ctx);
                      _fetchTickets();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support ticket raised. Priority team assigned.')),
                      );
                    } catch (e) {
                      setSheetState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'FAQs & Guides'),
            Tab(text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // FAQs Tab
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Contact Card
              EbicCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('24/7 Concierge Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Executive live chat & phone support available', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900)),
              const SizedBox(height: 12),

              ..._faqs.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EbicCard(
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                        title: Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900)),
                        children: [
                          Text(f['a']!, style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),

          // Tickets Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined, size: 56, color: AppColors.slate300),
                          const SizedBox(height: 12),
                          const Text('No support tickets raised', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('If you have any issues, tap below to raise a ticket.', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                          const SizedBox(height: 20),
                          EbicButton(
                            label: 'Raise Ticket',
                            icon: Icons.add,
                            onPressed: _showCreateTicketDialog,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final t = _tickets[idx];
                        return EbicCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t['category'] ?? 'SUPPORT',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                  ),
                                  StatusBadge(status: t['status'] ?? 'OPEN'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(t['subject'] ?? 'Ticket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(t['message'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
                            ],
                          ),
                        );
                      },
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('New Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showCreateTicketDialog,
      ),
    );
  }
}
