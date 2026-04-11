import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';
import 'package:coaching_client/core/widgets/riyal_text.dart';

class CoachBookingsPage extends StatefulWidget {
  const CoachBookingsPage({super.key});
  @override
  State<CoachBookingsPage> createState() => _CoachBookingsPageState();
}

class _CoachBookingsPageState extends State<CoachBookingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('الحجوزات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [Tab(text: 'القادمة'), Tab(text: 'جارية'), Tab(text: 'المكتملة')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(status: 'confirmed'),
          _BookingsList(status: 'in_progress'),
          _BookingsList(status: 'completed'),
        ],
      ),
    );
  }
}

class _BookingsList extends StatefulWidget {
  final String status;
  const _BookingsList({required this.status});
  @override
  State<_BookingsList> createState() => _BookingsListState();
}

class _BookingsListState extends State<_BookingsList> {
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getMyBookings(status: widget.status);
      setState(() {
        _bookings = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }


  Future<void> _sendQuestionnaire(BuildContext context, String bookingId) async {
    try {
      final res = await getIt<ApiClient>().getQuestionnaireSets();
      final sets = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (sets.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد استبيانات متاحة')));
        return;
      }
      if (!context.mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('اختر استبياناً لإرساله',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...sets.map((s) => ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(s['name'] as String? ?? ''),
                    subtitle: Text(s['description'] as String? ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${s['question_count'] ?? 0} سؤال',
                        style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(context, s['id'].toString()),
                  )),
            ],
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      await getIt<ApiClient>().sendSetToClient(selected, bookingId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم إرسال الاستبيان للعميل ✓'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  String get _emptyMsg => widget.status == 'confirmed'
      ? 'لا توجد حجوزات قادمة'
      : widget.status == 'in_progress'
          ? 'لا توجد جلسات جارية'
          : 'لا توجد جلسات مكتملة';

  static const Map<String, String> _typeLabels = {'video': 'جلسة', 'voice': 'جلسة', 'chat': 'دردشة'};
  static const Map<String, IconData> _typeIcons = {'video': Icons.phone_outlined, 'voice': Icons.phone_outlined, 'chat': Icons.chat_bubble_outline};

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(_emptyMsg, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) {
          final b = _bookings[i] as Map<String, dynamic>;
          final type = b['session_type'] as String? ?? 'chat';
          final price = b['price'];
          final clientName = b['client_name'] as String? ?? '—';
          final clientId = b['client_id']?.toString();
          final scheduledAt = b['scheduled_at'] as String?;
          final scheduledDateTime = scheduledAt != null ? DateTime.tryParse(scheduledAt)?.toLocal() : null;
          final now = DateTime.now();
          final canStart = scheduledDateTime != null &&
              now.isAfter(scheduledDateTime.subtract(const Duration(minutes: 15))) &&
              now.isBefore(scheduledDateTime.add(const Duration(hours: 2)));
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Icon(_typeIcons[type] ?? Icons.person, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (scheduledAt != null)
                              Text(
                                DateTime.tryParse(scheduledAt)?.toLocal().toString().substring(0, 16) ?? scheduledAt,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            Text(_typeLabels[type] ?? type, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (price != null)
                        RiyalText('$price', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      if (clientId != null)
                        IconButton(
                          icon: const Icon(Icons.assignment_outlined),
                          color: AppTheme.primaryColor,
                          tooltip: 'استبيان العميل',
                          onPressed: () => context.push(
                            '/coach/client-questionnaire/$clientId',
                            extra: {'clientName': clientName},
                          ),
                        ),
                    ],
                  ),
                  if (widget.status == 'in_progress') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => context.go(
                          '/coach/video/${b['id']}',
                          extra: {'sessionType': b['session_type'] as String? ?? 'video'},
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('انضم للجلسة الجارية'),
                      ),
                    ),
                  ] else if (widget.status == 'confirmed') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canStart ? () => context.go(
                              '/coach/video/${b['id']}',
                              extra: {'sessionType': b['session_type'] as String? ?? 'video'},
                            ) : null,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(canStart ? 'بدء الجلسة' : '${scheduledDateTime != null ? "${scheduledDateTime.hour.toString().padLeft(2,'0')}:${scheduledDateTime.minute.toString().padLeft(2,'0')}" : ""}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _sendQuestionnaire(context, b['id'].toString()),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('استبيان'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
