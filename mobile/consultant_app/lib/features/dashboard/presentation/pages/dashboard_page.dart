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

  @override
  void initState() {
    super.initState();
    _loadUser();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
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
                _StatsRow(),
                const SizedBox(height: 16),
                _TodaySessionsCard(),
                const SizedBox(height: 16),
                _PendingRequestsCard(),
                const SizedBox(height: 16),
                _WeeklyEarningsCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> stats = const [
    {'label': 'جلسات اليوم', 'value': '0', 'icon': Icons.today, 'color': Color(0xFF1A6B72)},
    {'label': 'هذا الأسبوع', 'value': '0', 'icon': Icons.calendar_view_week, 'color': Color(0xFFF5A623)},
    {'label': 'التقييم', 'value': '—', 'icon': Icons.star, 'color': Color(0xFFFF6B35)},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.map((s) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
                const SizedBox(height: 6),
                Text(s['value'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                const Text('جلسات اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(onPressed: () => context.go('/bookings'), child: const Text('عرض الكل')),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد جلسات اليوم', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsCard extends StatelessWidget {
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
        title: const Text('الطلبات المعلقة', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('اضغط لعرض الطلبات'),
        trailing: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        onTap: () => context.go('/bookings'),
      ),
    );
  }
}

class _WeeklyEarningsCard extends StatelessWidget {
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
                  gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أرباح هذا الأسبوع',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('0 ر.س',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            TextButton(onPressed: () => context.go('/earnings'), child: const Text('التفاصيل')),
          ],
        ),
      ),
    );
  }
}
