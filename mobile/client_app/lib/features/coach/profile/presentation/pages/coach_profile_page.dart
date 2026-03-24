import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../profile/presentation/pages/help_page.dart';

class CoachProfilePage extends StatefulWidget {
  const CoachProfilePage({super.key});
  @override
  State<CoachProfilePage> createState() => _CoachProfilePageState();
}

class _CoachProfilePageState extends State<CoachProfilePage> {
  Map<String, dynamic> _user = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final raw = getIt<StorageService>().getUser();
    if (raw != null) {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _user = user);
      // If name is empty, refresh from API
      if ((user['name'] as String?)?.isNotEmpty == true) return;
    }
    try {
      final res = await getIt<ApiClient>().getProfile();
      final user = res['data'] as Map<String, dynamic>? ?? {};
      await getIt<StorageService>().saveUser(jsonEncode(user));
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _user['name'] as String? ?? '');
    final bioCtrl = TextEditingController(text: _user['bio'] as String? ?? '');
    final yearsCtrl = TextEditingController(text: '${_user['years_experience'] ?? ''}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'نبذة تعريفية', prefixIcon: Icon(Icons.info_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yearsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سنوات الخبرة', prefixIcon: Icon(Icons.workspace_premium_outlined)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final years = int.tryParse(yearsCtrl.text.trim()) ?? 0;
                    await getIt<ApiClient>().updateProfile({'name': nameCtrl.text.trim()});
                    await getIt<ApiClient>().updateTherapistProfile({
                      'bio': bioCtrl.text.trim(),
                      'years_experience': years,
                    });
                    final updated = Map<String, dynamic>.from(_user)
                      ..['name'] = nameCtrl.text.trim()
                      ..['bio'] = bioCtrl.text.trim()
                      ..['years_experience'] = years;
                    await getIt<StorageService>().saveUser(jsonEncode(updated));
                    setState(() => _user = updated);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الحفظ'), backgroundColor: AppTheme.successColor),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
                      );
                    }
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
    final name = (_user['name'] as String?) ?? 'كوتش';
    final phone = (_user['phone'] as String?) ?? '';
    final bio = (_user['bio'] as String?) ?? '';
    final rating = _user['rating'];
    final totalReviews = _user['total_reviews'];

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
                if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(bio, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                ],
                if (rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(' $rating ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (totalReviews != null)
                        Text('($totalReviews تقييم)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _section('الإعدادات', [
            _tile(Icons.edit_outlined, 'تعديل الملف الشخصي', _editProfile),
            _tile(Icons.schedule_outlined, 'المواعيد المتاحة', () => context.go('/coach/schedule')),
            _tile(Icons.notifications_outlined, 'الإشعارات', () {}),
          ]),
          _section('الحساب', [
            _tile(Icons.help_outline, 'المساعدة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
            _tile(Icons.logout, 'تسجيل الخروج', () {
              context.read<AuthBloc>().add(LogoutEvent());
              context.go('/login');
            }, color: AppTheme.errorColor),
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
