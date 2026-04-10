import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/notification_service.dart';
import 'help_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _user = {};
  int _sessionCount = 0;

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
      if (mounted) setState(() => _user = user);
      if ((user['name'] as String?)?.isNotEmpty == true) return;
    }
    try {
      final res = await getIt<ApiClient>().getProfile();
      final user = res['data'] as Map<String, dynamic>? ?? {};
      await getIt<StorageService>().saveUser(jsonEncode(user));
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await getIt<ApiClient>().getMyBookings(status: 'completed');
      final list = (res['data'] as List?) ?? [];
      if (mounted) setState(() => _sessionCount = list.length);
    } catch (_) {}
  }

  Future<void> _handleNotifications() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      // Already granted — open system notification settings
      await openAppSettings();
    } else if (status.isPermanentlyDenied) {
      // Permanently denied — must open settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تفعيل الإشعارات'),
            content: const Text(
                'الإشعارات محجوبة. يرجى تفعيلها من إعدادات التطبيق.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );
      }
    } else {
      // Not yet asked — request permission
      await NotificationService.requestPermission();
      if (mounted) {
        final newStatus = await Permission.notification.status;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus.isGranted
              ? 'تم تفعيل الإشعارات'
              : 'لم يتم تفعيل الإشعارات'),
          backgroundColor: newStatus.isGranted
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ));
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/966536011433?text=مرحباً، أحتاج مساعدة في تطبيق كوتشينج');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showContactSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تواصل معنا', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('فريق الدعم متاح من 9 صباحاً حتى 11 مساءً',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            InkWell(
              onTap: () { Navigator.pop(ctx); _openWhatsApp(); },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('واتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('+966 50 000 0000', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _user['name'] as String? ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تعديل الملف الشخصي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await getIt<ApiClient>()
                        .updateProfile({'name': nameCtrl.text.trim()});
                    final updated = Map<String, dynamic>.from(_user)
                      ..['name'] = nameCtrl.text.trim();
                    await getIt<StorageService>().saveUser(jsonEncode(updated));
                    setState(() => _user = updated);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم الحفظ'),
                            backgroundColor: AppTheme.successColor));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('خطأ: $e'),
                            backgroundColor: AppTheme.errorColor));
                  }
                },
                child: const Text('حفظ'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user['name'] as String?) ?? 'المستخدم';
    final phone = (_user['phone'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('حسابي')),
      body: ListView(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.backgroundColor,
                  child: Icon(Icons.person, size: 48, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل الملف الشخصي'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(value: '$_sessionCount', label: 'جلسة مكتملة'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // جلساتي
          _MenuSection(title: 'جلساتي', items: [
            _MenuItem(
              icon: Icons.calendar_today_outlined,
              title: 'جلساتي',
              onTap: () => context.push('/my-bookings'),
            ),
            _MenuItem(
              icon: Icons.assignment_outlined,
              title: 'استبياني',
              onTap: () => context.push('/questionnaire'),
            ),
            _MenuItem(
              icon: Icons.payment_outlined,
              title: 'سجل المدفوعات',
              onTap: () => context.push('/my-payments'),
            ),
          ]),
          // الإعدادات
          _MenuSection(title: 'الإعدادات', items: [
            _MenuItem(
              icon: Icons.notifications_outlined,
              title: 'الإشعارات',
              onTap: _handleNotifications,
            ),
            _MenuItem(
              icon: Icons.lock_outline,
              title: 'الخصوصية',
              onTap: () => context.push('/privacy'),
            ),
          ]),
          // المساعدة
          _MenuSection(title: 'المساعدة', items: [
            _MenuItem(
              icon: Icons.help_outline,
              title: 'الأسئلة الشائعة',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage())),
            ),
            _MenuItem(
              icon: Icons.support_agent_outlined,
              title: 'تواصل معنا',
              onTap: () => _showContactSheet(context),
            ),
            _MenuItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              color: AppTheme.errorColor,
              onTap: () {
                context.read<AuthBloc>().add(LogoutEvent());
                context.go('/login');
              },
            ),
          ]),
          const SizedBox(height: 32),
          const Center(
            child: Text('كوتشينج v1.0.0',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ],
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppTheme.backgroundColor);
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ),
      Container(color: Colors.white, child: Column(children: items)),
      const SizedBox(height: 8),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  const _MenuItem(
      {required this.icon, required this.title, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? AppTheme.textPrimary),
    title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
    trailing: color == null
        ? const Icon(Icons.chevron_left, color: AppTheme.textSecondary)
        : null,
    onTap: onTap,
  );
}
