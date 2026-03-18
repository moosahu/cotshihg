import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/services/storage_service.dart';

class CoachProfilePage extends StatelessWidget {
  const CoachProfilePage({super.key});

  Map<String, dynamic> _getUser() {
    final raw = getIt<StorageService>().getUser();
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final user = _getUser();
    final name = (user['name'] as String?) ?? 'كوتش';
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('ملفي الشخصي')),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  children: [
                    const CircleAvatar(radius: 50, backgroundColor: AppTheme.backgroundColor, child: Icon(Icons.person, size: 56, color: AppTheme.primaryColor)),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('كوتش تطوير ذاتي', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' 4.9 ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('(128 تقييم)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _section('الإعدادات', [
            _tile(Icons.edit_outlined, 'تعديل الملف الشخصي', () {}),
            _tile(Icons.attach_money_outlined, 'أسعار الجلسات', () {}),
            _tile(Icons.notifications_outlined, 'الإشعارات', () {}),
          ]),
          _section('الدعم', [
            _tile(Icons.help_outline, 'المساعدة', () {}),
            _tile(Icons.logout, 'تسجيل الخروج', () => context.go('/login'), color: AppTheme.errorColor),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
      Container(color: Colors.white, child: Column(children: items)),
      const SizedBox(height: 8),
    ],
  );

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? AppTheme.textPrimary),
    title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
    trailing: color == null ? const Icon(Icons.chevron_left, color: AppTheme.textSecondary) : null,
    onTap: onTap,
  );
}
