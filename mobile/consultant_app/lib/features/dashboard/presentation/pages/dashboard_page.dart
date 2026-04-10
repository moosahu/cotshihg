import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/network/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isInstantAvailable = false;
  String _userName = '';
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
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
        _stats = res['data'] as Map<String, dynamic>?;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loadingStats = true);
          await _loadStats();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مرحباً، ${_userName.isNotEmpty ? _userName : 'كوتش'}',
                      style: const TextStyle(fontSize: 17)),
                  Text(
                    _isInstantAvailable ? 'متاح للجلسات الفورية' : 'غير متاح حالياً',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isInstantAvailable ? AppTheme.successColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Switch(
                    value: _isInstantAvailable,
                    onChanged: (v) => setState(() => _isInstantAvailable = v),
                    activeColor: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _loadingStats
                      ? const SizedBox(
                          height: 90,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : _StatsRow(stats: _stats),
                  const SizedBox(height: 16),
                  _TodaySessionsCard(
                    sessions: (_stats?['today_sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                    loading: _loadingStats,
                  ),
                  const SizedBox(height: 16),
                  _PendingRequestsCard(
                    pendingCount: (_stats?['pending_count'] as int?) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  _WeeklyEarningsCard(
                    earnings: (_stats?['week_earnings'] as num?)?.toDouble() ?? 0,
                    loading: _loadingStats,
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

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatsRow({this.stats});

  @override
  Widget build(BuildContext context) {
    final todayCount = (stats?['today_count'] as int?) ?? 0;
    final weekCount = (stats?['week_count'] as int?) ?? 0;
    final rating = stats?['rating']?.toString();

    final items = [
      {'label': 'جلسات اليوم', 'value': '$todayCount', 'icon': Icons.today, 'color': const Color(0xFF1A6B72)},
      {'label': 'هذا الأسبوع', 'value': '$weekCount', 'icon': Icons.calendar_view_week, 'color': const Color(0xFFF5A623)},
      {'label': 'التقييم', 'value': rating ?? '—', 'icon': Icons.star, 'color': const Color(0xFFFF6B35)},
    ];

    return Row(
      children: items.map((s) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
                const SizedBox(height: 6),
                Text(s['value'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(s['label'] as String,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _TodaySessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  const _TodaySessionsCard({required this.sessions, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                TextButton(onPressed: () => context.go('/bookings'), child: const Text('عرض الكل')),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else if (sessions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد جلسات اليوم',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              ...sessions.map((s) {
                final name = s['client_name'] as String? ?? 'عميل';
                final type = s['session_type'] as String? ?? '';
                final scheduled = s['scheduled_at'] as String?;
                final dt = scheduled != null ? DateTime.tryParse(scheduled)?.toLocal() : null;
                final timeStr = dt != null
                    ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                    : '';
                final typeIcon = type == 'video'
                    ? Icons.videocam_outlined
                    : type == 'voice'
                        ? Icons.phone_outlined
                        : Icons.chat_bubble_outline;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(typeIcon, color: AppTheme.primaryColor, size: 18),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(timeStr,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsCard extends StatelessWidget {
  final int pendingCount;
  const _PendingRequestsCard({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.pending_actions_outlined, color: AppTheme.warningColor),
        ),
        title: const Text('الطلبات المعلقة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(pendingCount > 0 ? '$pendingCount طلب بانتظار موافقتك' : 'لا توجد طلبات معلقة'),
        trailing: pendingCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('$pendingCount',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              )
            : const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        onTap: () => context.go('/bookings'),
      ),
    );
  }
}

class _WeeklyEarningsCard extends StatelessWidget {
  final double earnings;
  final bool loading;
  const _WeeklyEarningsCard({required this.earnings, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  loading
                      ? const SizedBox(
                          height: 28,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                      : Text('${earnings.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                ],
              ),
            ),
            TextButton(
                onPressed: () => context.go('/earnings'),
                child: const Text('التفاصيل')),
          ],
        ),
      ),
    );
  }
}
