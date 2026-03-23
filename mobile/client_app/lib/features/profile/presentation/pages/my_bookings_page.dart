import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});
  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'القادمة'),
            Tab(text: 'المعلقة'),
            Tab(text: 'المكتملة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(status: 'confirmed'),
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

class _BookingsListState extends State<_BookingsList>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await getIt<ApiClient>().getMyBookings(status: widget.status);
      if (mounted) setState(() {
        _bookings = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await getIt<ApiClient>().cancelBooking(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('لا توجد حجوزات', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
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
          final coachName = b['therapist_name'] as String? ?? 'الكوتش';
          final scheduledAt = b['scheduled_at'] as String?;
          final dateStr = scheduledAt != null
              ? DateTime.tryParse(scheduledAt)
                      ?.toLocal()
                      .toString()
                      .substring(0, 16) ??
                  scheduledAt
              : '';
          final sessionType = b['session_type'] as String? ?? '';
          final price = b['price_paid'] ?? b['session_price'] ?? 0;
          final id = b['id'].toString();

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
                        child: const Icon(Icons.person, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(coachName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(dateStr,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 12)),
                            if (sessionType.isNotEmpty)
                              Text(sessionType,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$price ر.س',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  if (widget.status == 'confirmed') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/chat/$id'),
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('ابدأ الجلسة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _cancel(id),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side: const BorderSide(color: AppTheme.errorColor)),
                          child: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ] else if (widget.status == 'pending') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _cancel(id),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor)),
                        child: const Text('إلغاء الحجز'),
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
