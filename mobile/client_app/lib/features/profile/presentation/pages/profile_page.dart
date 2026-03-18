import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
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
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'اسم المستخدم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '+966 5X XXX XXXX',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('تعديل الملف الشخصي'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(value: '0', label: 'جلسة'),
                _StatDivider(),
                _ProfileStat(value: '0', label: 'يوم متابعة'),
                _StatDivider(),
                _ProfileStat(value: '0', label: 'هدف مكتمل'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Menu
          _MenuSection(
            title: 'جلساتي',
            items: [
              _MenuItem(
                icon: Icons.calendar_today_outlined,
                title: 'حجوزاتي',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.history_outlined,
                title: 'سجل الجلسات',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.payment_outlined,
                title: 'المدفوعات',
                onTap: () {},
              ),
            ],
          ),
          _MenuSection(
            title: 'الإعدادات',
            items: [
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'الإشعارات',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                title: 'الخصوصية',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.language_outlined,
                title: 'اللغة',
                onTap: () {},
              ),
            ],
          ),
          _MenuSection(
            title: 'المساعدة',
            items: [
              _MenuItem(
                icon: Icons.help_outline,
                title: 'الأسئلة الشائعة',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.support_agent_outlined,
                title: 'تواصل معنا',
                onTap: () {},
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
            ],
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Coaching v1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppTheme.backgroundColor);
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: items),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textPrimary),
      title: Text(
        title,
        style: TextStyle(color: color ?? AppTheme.textPrimary),
      ),
      trailing: color == null
          ? const Icon(Icons.chevron_left, color: AppTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }
}
