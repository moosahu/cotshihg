import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/network/api_client.dart';

class CoachDashboardPage extends StatefulWidget {
  const CoachDashboardPage({super.key});
  @override
  State<CoachDashboardPage> createState() => _CoachDashboardPageState();
}

class _CoachDashboardPageState extends State<CoachDashboardPage> {
  bool _isInstantAvailable = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUser() async {
    final raw = getIt<StorageService>().getUser();
    if (raw != null) {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      final name = (user['name'] as String?) ?? '';
      if (name.isNotEmpty) {
        if (mounted) setState(() => _userName = name);
        // Still load instant availability from API
        _loadInstantStatus();
        return;
      }
    }
    try {
      final res = await getIt<ApiClient>().getProfile();
      final user = res['data'] as Map<String, dynamic>? ?? {};
      final name = (user['name'] as String?) ?? '';
      await getIt<StorageService>().saveUser(jsonEncode(user));
      if (mounted) setState(() => _userName = name);
    } catch (_) {}
    _loadInstantStatus();
  }

  Future<void> _loadInstantStatus() async {
    try {
      final res = await getIt<ApiClient>().getProfile();
      final user = res['data'] as Map<String, dynamic>? ?? {};
      // isAvailableInstant stored in therapist profile
      final isAvail = user['is_available_instant'] as bool? ?? false;
      if (mounted) setState(() => _isInstantAvailable = isAvail);
    } catch (_) {}
  }

  Future<void> _toggleInstant(bool value) async {
    setState(() => _isInstantAvailable = value);
    try {
      await getIt<ApiClient>().toggleInstantAvailability(value);
    } catch (e) {
      // revert on error
      if (mounted) {
        setState(() => _isInstantAvailable = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
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
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً، ${_userName.isNotEmpty ? _userName : 'كوتش'}', style: const TextStyle(fontSize: 17)),
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
                  onChanged: _toggleInstant,
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
                Text(s['label'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), textAlign: TextAlign.center),
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
                TextButton(onPressed: () => context.go('/coach/bookings'), child: const Text('عرض الكل')),
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
    final isPending = session['status'] == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Icon(typeIcons[session['type']] ?? Icons.circle, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(session['time'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (isPending)
            Row(children: [
              IconButton(icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.cancel_outlined, color: AppTheme.errorColor), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ])
          else
            ElevatedButton(
              onPressed: () => context.go('/coach/video/booking_id'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
              child: const Text('ابدأ', style: TextStyle(fontSize: 13)),
            ),
        ],
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
          decoration: BoxDecoration(color: AppTheme.warningColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.pending_actions_outlined, color: AppTheme.warningColor),
        ),
        title: const Text('الطلبات المعلقة', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('اضغط لعرض الطلبات'),
        trailing: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        onTap: () => context.go('/coach/bookings'),
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
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أرباح هذا الأسبوع', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('0 ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            TextButton(onPressed: () => context.go('/coach/earnings'), child: const Text('التفاصيل')),
          ],
        ),
      ),
    );
  }
}
