import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/network/api_client.dart';
import 'package:coaching_client/core/widgets/riyal_text.dart';

class CoachDashboardPage extends StatefulWidget {
  const CoachDashboardPage({super.key});
  @override
  State<CoachDashboardPage> createState() => _CoachDashboardPageState();
}

class _CoachDashboardPageState extends State<CoachDashboardPage> {
  String _userName = '';
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final list = await getIt<ApiClient>().getNotifications();
      final unread = list.where((n) => n['is_read'] == false).length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final raw = getIt<StorageService>().getUser();
    if (raw != null) {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      final name = (user['name'] as String?) ?? '';
      if (name.isNotEmpty) {
        if (mounted) setState(() => _userName = name);
        return;
      }
    }
    try {
      final res = await getIt<ApiClient>().getProfile();
      final user = res['data'] as Map<String, dynamic>? ?? {};
      await getIt<StorageService>().saveUser(jsonEncode(user));
      if (mounted) setState(() => _userName = (user['name'] as String?) ?? '');
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await getIt<ApiClient>().getCoachDashboardStats();
      if (mounted) setState(() {
        _stats = (res['data'] as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayCount = _stats['today_count'] ?? 0;
    final weekCount = _stats['week_count'] ?? 0;
    final weekEarnings = (_stats['week_earnings'] ?? 0).toStringAsFixed(0);
    final rating = _stats['rating'];
    final todaySessions = (_stats['today_sessions'] as List?) ?? [];
    final pendingCount = _stats['pending_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async { await _loadStats(); },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              title: Text(
                'مرحباً، ${_userName.isNotEmpty ? _userName : 'كوتش'}',
                style: const TextStyle(fontSize: 17),
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () async {
                        await context.push('/notifications');
                        _loadUnreadCount();
                      },
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _loading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()))
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Stats Row ──
                        Row(
                          children: [
                            _StatCard(label: 'جلسات اليوم', value: '$todayCount',
                                icon: Icons.today, color: const Color(0xFF1A6B72)),
                            _StatCard(label: 'هذا الأسبوع', value: '$weekCount',
                                icon: Icons.calendar_view_week, color: const Color(0xFFF5A623)),
                            _StatCard(
                                label: 'التقييم',
                                value: rating != null ? '$rating' : '—',
                                icon: Icons.star,
                                color: const Color(0xFFFF6B35)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── جلسات اليوم ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('جلسات اليوم',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    TextButton(
                                        onPressed: () => context.go('/coach/bookings'),
                                        child: const Text('عرض الكل')),
                                  ],
                                ),
                                if (todaySessions.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text('لا توجد جلسات اليوم',
                                          style: TextStyle(color: AppTheme.textSecondary)),
                                    ),
                                  )
                                else
                                  ...todaySessions.map((s) => _SessionTile(session: s as Map<String, dynamic>)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── الطلبات المعلقة ──
                        Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.pending_actions_outlined,
                                  color: AppTheme.warningColor),
                            ),
                            title: const Text('الطلبات المعلقة',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              pendingCount > 0 ? '$pendingCount طلب بانتظار موافقتك' : 'لا توجد طلبات معلقة',
                              style: TextStyle(
                                  color: pendingCount > 0 ? AppTheme.warningColor : AppTheme.textSecondary),
                            ),
                            trailing: pendingCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                        color: AppTheme.warningColor, shape: BoxShape.circle),
                                    child: Text('$pendingCount',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  )
                                : const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                            onTap: () => context.go('/coach/bookings'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── أرباح هذا الأسبوع ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.account_balance_wallet_outlined,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('أرباح هذا الأسبوع',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                      RiyalText(weekEarnings,
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                    onPressed: () => context.go('/coach/earnings'),
                                    child: const Text('التفاصيل')),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  static const Map<String, IconData> typeIcons = {
    'video': Icons.videocam_outlined,
    'voice': Icons.mic_outlined,
    'chat': Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final clientName = session['client_name'] as String? ?? 'عميل';
    final sessionType = session['session_type'] as String? ?? 'video';
    final scheduledAt = session['scheduled_at'] as String?;
    final timeStr = scheduledAt != null
        ? TimeOfDay.fromDateTime(DateTime.parse(scheduledAt).toLocal())
            .format(context)
        : '';
    final bookingId = session['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Icon(typeIcons[sessionType] ?? Icons.circle,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/coach/video/$bookingId',
                extra: {'sessionType': sessionType}),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero),
            child: const Text('ابدأ', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
