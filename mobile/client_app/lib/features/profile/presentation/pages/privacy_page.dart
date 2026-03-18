import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية وسياسة الاستخدام')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Section(
            title: 'جمع البيانات',
            body:
                'نجمع المعلومات التي تقدمها عند التسجيل مثل رقم الجوال والاسم، بالإضافة إلى بيانات استخدام التطبيق لتحسين تجربتك.',
          ),
          _Section(
            title: 'استخدام البيانات',
            body:
                'تُستخدم بياناتك لتقديم الخدمة وتحسينها، والتواصل معك بشأن جلساتك وحجوزاتك. لن نشارك بياناتك مع أطراف ثالثة دون موافقتك.',
          ),
          _Section(
            title: 'الجلسات والمحادثات',
            body:
                'جميع محادثاتك مع الكوتشز تبقى سرية. لا يتم الاطلاع عليها إلا بموافقتك أو بموجب أمر قانوني.',
          ),
          _Section(
            title: 'الأمان',
            body:
                'نستخدم تشفير SSL لحماية بياناتك أثناء النقل. جميع كلمات المرور والرموز مشفرة ومحمية.',
          ),
          _Section(
            title: 'حذف الحساب',
            body:
                'يمكنك طلب حذف حسابك وجميع بياناتك المرتبطة به في أي وقت عبر التواصل مع الدعم على support@coaching.app.',
          ),
          _Section(
            title: 'التحديثات',
            body:
                'قد نحدث هذه السياسة من وقت لآخر. سيتم إشعارك بأي تغييرات جوهرية عبر التطبيق.',
          ),
          SizedBox(height: 16),
          Text(
            'آخر تحديث: مارس 2026',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }
}
