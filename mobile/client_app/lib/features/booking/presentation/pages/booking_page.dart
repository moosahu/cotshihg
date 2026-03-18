import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class BookingPage extends StatefulWidget {
  final String therapistId;
  const BookingPage({super.key, required this.therapistId});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _sessionType = 'video';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حجز جلسة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اختر نوع الجلسة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _SessionTypeCard(
              type: 'chat',
              label: 'محادثة نصية',
              icon: Icons.chat_bubble_outline,
              selected: _sessionType == 'chat',
              onTap: () => setState(() => _sessionType = 'chat'),
            ),
            const SizedBox(height: 8),
            _SessionTypeCard(
              type: 'voice',
              label: 'مكالمة صوتية',
              icon: Icons.phone_outlined,
              selected: _sessionType == 'voice',
              onTap: () => setState(() => _sessionType = 'voice'),
            ),
            const SizedBox(height: 8),
            _SessionTypeCard(
              type: 'video',
              label: 'مكالمة فيديو',
              icon: Icons.videocam_outlined,
              selected: _sessionType == 'video',
              onTap: () => setState(() => _sessionType = 'video'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('تأكيد الحجز'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTypeCard extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SessionTypeCard({
    required this.type,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(color: selected ? AppTheme.primaryColor : const Color(0xFFE0E0E0), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
