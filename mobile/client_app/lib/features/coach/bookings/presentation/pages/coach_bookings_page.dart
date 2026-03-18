import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
          tabs: const [Tab(text: 'القادمة'), Tab(text: 'جارية'), Tab(text: 'المعلقة'), Tab(text: 'المكتملة')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(status: 'confirmed'),
          _BookingsList(status: 'in_progress'),
          _BookingsList(status: 'pending'),
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

  String get _emptyMsg => widget.status == 'confirmed'
      ? 'لا توجد حجوزات قادمة'
      : widget.status == 'in_progress'
          ? 'لا توجد جلسات جارية'
          : widget.status == 'pending'
              ? 'لا توجد طلبات معلقة'
              : 'لا توجد جلسات مكتملة';

  static const Map<String, String> _typeLabels = {'video': 'فيديو', 'voice': 'صوتي', 'chat': 'دردشة'};
  static const Map<String, IconData> _typeIcons = {'video': Icons.videocam_outlined, 'voice': Icons.mic_outlined, 'chat': Icons.chat_bubble_outline};

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
          final scheduledAt = b['scheduled_at'] as String?;
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
                        Text('$price ر.س', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (widget.status == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await getIt<ApiClient>().confirmBooking(b['id'].toString());
                              _load();
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
                            }
                          },
                          child: const Text('قبول'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await getIt<ApiClient>().cancelBooking(b['id'].toString());
                              _load();
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
                            }
                          },
                          child: const Text('رفض'),
                        )),
                      ],
                    ),
                  ] else if (widget.status == 'in_progress') ...[
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(
                          '/coach/video/${b['id']}',
                          extra: {'sessionType': b['session_type'] as String? ?? 'video'},
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('بدء الجلسة'),
                      ),
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
