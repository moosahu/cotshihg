import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    (
      q: 'كيف أحجز جلسة مع كوتش؟',
      a: 'من الصفحة الرئيسية اختر الكوتش المناسب، ثم اضغط "احجز جلسة"، اختر نوع الجلسة (فيديو / صوت / دردشة) والوقت المناسب، ثم أكمل الدفع.',
    ),
    (
      q: 'ما الفرق بين الجلسة الفورية والجلسة المجدولة؟',
      a: 'الجلسة الفورية تبدأ مباشرة مع كوتش متاح الآن. الجلسة المجدولة تختار لها وقتاً محدداً مسبقاً من جدول الكوتش.',
    ),
    (
      q: 'كيف أنضم لجلسة فيديو أو صوت؟',
      a: 'عند حلول موعد الجلسة، اذهب لـ "حجوزاتي" في حسابي واضغط "ابدأ الجلسة". تأكد من السماح بالكاميرا والميكروفون.',
    ),
    (
      q: 'كم تستغرق الجلسة الواحدة؟',
      a: 'مدة كل جلسة 45 دقيقة. سيظهر مؤقت تنازلي في أعلى الشاشة أثناء الجلسة.',
    ),
    (
      q: 'كيف أتواصل مع الكوتش عبر الدردشة؟',
      a: 'من تفاصيل الحجز اختر "دردشة". يمكنك إرسال رسائل نصية وصور.',
    ),
    (
      q: 'كيف أعدّل بياناتي الشخصية؟',
      a: 'من صفحة "حسابي" اضغط "تعديل الملف الشخصي" وغيّر الاسم.',
    ),
    (
      q: 'ماذا أفعل إذا واجهت مشكلة تقنية؟',
      a: 'تأكد من اتصالك بالإنترنت، ثم أغلق التطبيق وأعد فتحه. إذا استمرت المشكلة تواصل معنا عبر واتساب.',
    ),
    (
      q: 'هل بياناتي وجلساتي سرية؟',
      a: 'نعم، جميع جلساتك ومعلوماتك الشخصية محمية وسرية تماماً وفق سياسة الخصوصية.',
    ),
  ];

  void _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/966500000000?text=مرحباً، أحتاج مساعدة في تطبيق كوتشينج');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب')),
        );
      }
    }
  }

  void _openEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:support@coaching.app?subject=طلب مساعدة');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح البريد الإلكتروني')),
        );
      }
    }
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تواصل معنا',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('فريق الدعم متاح من 9 صباحاً حتى 11 مساءً',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            _ContactOption(
              icon: Icons.chat,
              iconColor: const Color(0xFF25D366),
              title: 'واتساب',
              subtitle: '+966 50 000 0000',
              onTap: () { Navigator.pop(context); _openWhatsApp(context); },
            ),
            const SizedBox(height: 12),
            _ContactOption(
              icon: Icons.email_outlined,
              iconColor: AppTheme.primaryColor,
              title: 'البريد الإلكتروني',
              subtitle: 'support@coaching.app',
              onTap: () { Navigator.pop(context); _openEmail(context); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة والدعم')),
      body: ListView(
        children: [
          // Contact banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('هل تحتاج مساعدة؟',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('فريق الدعم جاهز للمساعدة',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showContactSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('تواصل', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // FAQ
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('الأسئلة الشائعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...List.generate(_faqs.length, (i) {
            final faq = _faqs[i];
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                title: Text(faq.q,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                iconColor: AppTheme.primaryColor,
                collapsedIconColor: AppTheme.textSecondary,
                children: [
                  Text(faq.a,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
