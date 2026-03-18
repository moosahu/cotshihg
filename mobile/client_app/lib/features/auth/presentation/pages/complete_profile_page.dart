import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _nameController = TextEditingController();
  String? _gender;
  String _role = 'client';
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أكمل ملفك الشخصي')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final role = state.user['role'] as String? ?? 'client';
            context.go((role == 'coach' || role == 'therapist') ? '/coach/dashboard' : '/home');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ: ${state.message}'), backgroundColor: Colors.red),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.backgroundColor,
                        child: Icon(Icons.person, size: 56, color: AppTheme.textSecondary),
                      ),
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
                ),
                const SizedBox(height: 32),

                // ─── Role Selection ───
                const Text('أنا...', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _RoleCard(
                      icon: Icons.person_outline,
                      label: 'عميل',
                      subtitle: 'أبحث عن كوتش',
                      selected: _role == 'client',
                      onTap: () => setState(() => _role = 'client'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _RoleCard(
                      icon: Icons.psychology_outlined,
                      label: 'كوتش',
                      subtitle: 'أقدم جلسات',
                      selected: _role == 'coach',
                      onTap: () => setState(() => _role = 'coach'),
                    )),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Name ───
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'أدخل اسمك' : null,
                ),
                const SizedBox(height: 16),

                // ─── Gender ───
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'الجنس',
                    prefixIcon: Icon(Icons.wc_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'اختر الجنس' : null,
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    // Save locally first so navigation works even if backend is slow
                    final storage = getIt<StorageService>();
                    final currentUser = storage.getUser();
                    final userMap = currentUser != null
                        ? jsonDecode(currentUser) as Map<String, dynamic>
                        : <String, dynamic>{};
                    userMap['name'] = _nameController.text.trim();
                    userMap['gender'] = _gender;
                    userMap['role'] = _role;
                    await storage.saveUser(jsonEncode(userMap));
                    // Try to sync with backend (fire and forget)
                    context.read<AuthBloc>().add(RegisterEvent(
                      name: _nameController.text.trim(),
                      gender: _gender!,
                      role: _role,
                    ));
                    // Navigate immediately without waiting
                    context.go(_role == 'coach' ? '/coach/dashboard' : '/home');
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                  child: const Text('حفظ والمتابعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppTheme.primaryColor : AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
