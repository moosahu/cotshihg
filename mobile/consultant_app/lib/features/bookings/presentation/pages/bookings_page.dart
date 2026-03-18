import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> with SingleTickerProviderStateMixin {
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
        title: const Text('الحجوزات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [Tab(text: 'القادمة'), Tab(text: 'المعلقة'), Tab(text: 'المكتملة')],
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

class _BookingsListState extends State<_BookingsList> with AutomaticKeepAliveClientMixin {
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
      final res = await getIt<ApiClient>().getMyBookings(status: widget.status);
      if (mounted) setState(() {
        _bookings = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد حجوزات', style: TextStyle(color: AppTheme.textSecondary)),
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
          final clientName = b['client_name'] as String? ?? 'عميل';
          final scheduledAt = b['scheduled_at'] as String?;
          final dateStr = scheduledAt != null
              ? DateTime.tryParse(scheduledAt)?.toLocal().toString().substring(0, 16) ?? scheduledAt
              : '';
          final price = b['price_paid'] ?? b['session_price'] ?? 0;
          final id = b['id'].toString();
          final sessionType = b['session_type'] as String? ?? '';

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
                          child: const Icon(Icons.person, color: AppTheme.primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(dateStr,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            if (sessionType.isNotEmpty)
                              Text(sessionType,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('$price ر.س',
                          style: const TextStyle(
                              color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.status == 'pending') ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await getIt<ApiClient>().confirmBooking(id);
                                _load();
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
                              }
                            },
                            child: const Text('قبول'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                await getIt<ApiClient>().cancelBooking(id);
                                _load();
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
                              }
                            },
                            child: const Text('رفض'),
                          ),
                        ),
                      ] else if (widget.status == 'confirmed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/video/$id'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('بدء الجلسة'),
                          ),
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
}
