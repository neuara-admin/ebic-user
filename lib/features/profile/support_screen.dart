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
  List<Map<String, dynamic>> _articles = [];
  bool _isLoadingTickets = true;
  bool _isLoadingArticles = false;
  String _faqSearch = '';
  String _selectedFaqCategory = 'ALL';

  // Section 33 Support Categories (aligned with backend SupportTicketCategory enum)
  final List<String> _categories = [
    'ORDER',
    'CHEF',
    'PAYMENT',
    'REFUND',
    'HEALTH_PASS',
    'CONSULTATION',
    'DIET_PLAN',
    'ACCOUNT',
    'PROMOTION',
    'TECHNICAL',
    'OTHER',
  ];

  final List<Map<String, String>> _fallbackFaqs = [
    {
      'title': 'How does EBIC automatic chef assignment work?',
      'category': 'CHEF',
      'content': 'Customers do not manually select chefs. Once your quote is paid, our backend assignment engine matches the nearest qualified executive chef based on proximity, culinary tier, and live shift capacity.'
    },
    {
      'title': 'What is the dynamic cooking time engine?',
      'category': 'BOOKING',
      'content': 'Cooking time is calculated from recipe dependencies, batch overlap, portion count, and plating rules. Times are never hard-coded or multiplied directly.'
    },
    {
      'title': 'How does Health Pass differ from Chef Booking?',
      'category': 'HEALTH_PASS',
      'content': 'Health Pass is a separate clinical subscription owning dietitians, consultations, diet plans, and health profiles. Chef Booking is an on-demand culinary dispatch service.'
    },
    {
      'title': 'How are refunds handled?',
      'category': 'REFUND',
      'content': 'Refund requests are automatically evaluated based on cancellation policies. Once approved, refunds are credited back to your original payment method or wallet.'
    },
    {
      'title': 'How are ingredients handled?',
      'category': 'BOOKING',
      'content': 'Every confirmed booking generates a preparation checklist indicating customer-supplied staples and EBIC-supplied gourmet spices.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchTickets();
    _fetchArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchArticles() async {
    setState(() => _isLoadingArticles = true);
    try {
      final res = await _api.get<dynamic>(ApiEndpoints.supportArticles);
      if (res.success && res.data != null) {
        final raw = res.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['items'] is List) {
          list = raw['items'];
        }
        if (list.isNotEmpty && mounted) {
          setState(() {
            _articles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoadingArticles = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _articles = _fallbackFaqs.map((f) => Map<String, dynamic>.from(f)).toList();
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      final res = await _api.get<dynamic>(ApiEndpoints.supportTickets);
      if (res.success && res.data != null) {
        final raw = res.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['items'] is List) {
          list = raw['items'];
        } else if (raw is Map && raw['tickets'] is List) {
          list = raw['tickets'];
        }
        if (mounted) {
          setState(() {
            _tickets = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoadingTickets = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingTickets = false);
    }
  }

  void _showCreateTicketDialog({String? prefillCategory, String? prefillOrderId}) {
    String selectedCategory = prefillCategory ?? _categories.first;
    if (selectedCategory == 'BOOKING') {
      selectedCategory = 'ORDER';
    }
    if (!_categories.contains(selectedCategory)) {
      selectedCategory = _categories.first;
    }
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
                    const Expanded(
                      child: Text(
                        'Raise Support Ticket',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                if (prefillOrderId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Linked to Order #$prefillOrderId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Issue Category'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(),
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
                      final Map<String, dynamic> body = {
                        'category': selectedCategory,
                        'subject': subjectCtrl.text.trim(),
                        'description': messageCtrl.text.trim(),
                      };
                      if (prefillOrderId != null) {
                        body['orderId'] = prefillOrderId;
                      }

                      await _api.post<Map<String, dynamic>>(
                        ApiEndpoints.supportTickets,
                        body: body,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchTickets();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support ticket raised. Priority team assigned.')),
                        );
                      }
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

  void _openTicketChat(Map<String, dynamic> ticket) {
    final ticketId = ticket['id']?.toString() ?? '';
    final ticketNumber = ticket['ticketNumber'] ?? 'Ticket';
    final status = (ticket['status'] ?? 'OPEN').toString().toUpperCase();
    final msgCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    List<dynamic> messages = (ticket['messages'] as List<dynamic>?) ?? [];
    bool isSending = false;
    bool isLoadingMessages = messages.isEmpty;
    bool isTicketClosed = status == 'CLOSED' || status == 'CANCELLED';
    bool hasRequestedFetch = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!hasRequestedFetch && ticketId.isNotEmpty) {
            hasRequestedFetch = true;
            _api.get<dynamic>(ApiEndpoints.supportTicketMessages(ticketId)).then((res) {
              if (ctx.mounted && res.success && res.data != null) {
                final raw = res.data;
                List<dynamic> loaded = [];
                if (raw is List) {
                  loaded = raw;
                } else if (raw is Map && raw['messages'] is List) {
                  loaded = raw['messages'];
                }
                setModalState(() {
                  messages = loaded;
                  isLoadingMessages = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollCtrl.hasClients) {
                    scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
                  }
                });
              } else if (ctx.mounted) {
                setModalState(() {
                  isLoadingMessages = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) {
                setModalState(() {
                  isLoadingMessages = false;
                });
              }
            });
          }

          return Material(
            color: Colors.transparent,
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              padding: EdgeInsets.only(
                top: 14,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#$ticketNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(
                              ticket['subject'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          StatusBadge(status: status),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Messages list
                  Expanded(
                    child: isLoadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.slate300),
                                      const SizedBox(height: 10),
                                      Text(
                                        ticket['description'] ?? 'No messages yet.',
                                        style: const TextStyle(color: AppColors.slate600, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: messages.length,
                                itemBuilder: (ctx, i) {
                                  final m = messages[i];
                                  final senderType = (m['senderType'] ?? 'CUSTOMER').toString().toUpperCase();
                                  final isMe = senderType == 'CUSTOMER';
                                  return Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                                      decoration: BoxDecoration(
                                        color: isMe ? AppColors.primary : AppColors.slate100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isMe ? 'You' : 'EBIC Support',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isMe ? Colors.white70 : AppColors.slate500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (m['message'] ?? '').toString(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isMe ? Colors.white : AppColors.slate900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Bottom input or closed alert
                  if (isTicketClosed)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 18, color: AppColors.slate500),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This ticket is closed.',
                              style: TextStyle(fontSize: 12, color: AppColors.slate600),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await _api.post(ApiEndpoints.supportTicketReopen(ticketId), body: {'reason': 'Customer requested reopen'});
                                Navigator.pop(ctx);
                                _fetchTickets();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ticket reopened')),
                                );
                              } catch (err) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not reopen: $err')),
                                );
                              }
                            },
                            child: const Text('Reopen'),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: msgCtrl,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: isSending
                              ? null
                              : () async {
                                  final text = msgCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  setModalState(() => isSending = true);
                                  try {
                                    await _api.post(
                                      ApiEndpoints.supportTicketMessages(ticketId),
                                      body: {'message': text},
                                    );
                                    msgCtrl.clear();
                                    setModalState(() {
                                      messages.add({
                                        'senderType': 'CUSTOMER',
                                        'message': text,
                                        'createdAt': DateTime.now().toIso8601String(),
                                      });
                                      isSending = false;
                                    });
                                    _fetchTickets();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (scrollCtrl.hasClients) {
                                        scrollCtrl.animateTo(
                                          scrollCtrl.position.maxScrollExtent,
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    });
                                  } catch (e) {
                                    setModalState(() => isSending = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to send: $e')),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _articles.where((a) {
      final matchesSearch = _faqSearch.isEmpty ||
          (a['title'] ?? '').toString().toLowerCase().contains(_faqSearch.toLowerCase()) ||
          (a['content'] ?? '').toString().toLowerCase().contains(_faqSearch.toLowerCase());
      final matchesCat = _selectedFaqCategory == 'ALL' ||
          (a['category'] ?? '').toString().toUpperCase() == _selectedFaqCategory;
      return matchesSearch && matchesCat;
    }).toList();

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
          RefreshIndicator(
            onRefresh: _fetchArticles,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Concierge banner
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
                            Text('Dedicated customer support across orders, diet plans & health pass.', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 61: Search Input
                TextField(
                  onChanged: (v) => setState(() => _faqSearch = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search help topics...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate200),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedFaqCategory == 'ALL',
                        onSelected: (val) {
                          if (val) setState(() => _selectedFaqCategory = 'ALL');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Chef Booking'),
                        selected: _selectedFaqCategory == 'BOOKING' || _selectedFaqCategory == 'CHEF',
                        onSelected: (val) {
                          if (val) setState(() => _selectedFaqCategory = 'BOOKING');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Health Pass'),
                        selected: _selectedFaqCategory == 'HEALTH_PASS',
                        onSelected: (val) {
                          if (val) setState(() => _selectedFaqCategory = 'HEALTH_PASS');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Refunds'),
                        selected: _selectedFaqCategory == 'REFUND',
                        onSelected: (val) {
                          if (val) setState(() => _selectedFaqCategory = 'REFUND');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900)),
                const SizedBox(height: 12),

                if (_isLoadingArticles)
                  const Center(child: CircularProgressIndicator())
                else if (filteredFaqs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('No articles found matching "$_faqSearch"', style: TextStyle(color: AppColors.slate500)),
                    ),
                  )
                else
                  ...filteredFaqs.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EbicCard(
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                            title: Text(
                              (f['title'] ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                            ),
                            children: [
                              Text(
                                (f['content'] ?? '').toString(),
                                style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
          ),

          // Tickets Tab
          _isLoadingTickets
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
                            onPressed: () => _showCreateTicketDialog(),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTickets,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final t = _tickets[idx];
                          final ticketNum = t['ticketNumber'] ?? '';
                          return EbicCard(
                            onTap: () => _openTicketChat(t),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ticketNum.isNotEmpty ? '#$ticketNum' : (t['category'] ?? 'SUPPORT'),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: t['status'] ?? 'OPEN'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(t['subject'] ?? 'Ticket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  t['description'] ?? t['message'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('New Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateTicketDialog(),
      ),
    );
  }
}
