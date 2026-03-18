import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  String _selected = 'الكل';
  final List<String> _categories = [
    'الكل',
    'تطوير ذاتي',
    'إنتاجية',
    'علاقات',
    'قيادة',
    'صحة نفسية',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحتوى التثقيفي')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: _selected == cat,
                    onSelected: (_) => setState(() => _selected = cat),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 8,
              itemBuilder: (_, i) => _ContentCard(index: i),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final int index;
  const _ContentCard({required this.index});

  static const List<Map<String, String>> _items = [
    {
      'title': 'كيف تحدد أهدافك بذكاء',
      'category': 'تطوير ذاتي',
      'duration': '5 دقائق',
    },
    {
      'title': 'أسرار الإنتاجية العالية',
      'category': 'إنتاجية',
      'duration': '8 دقائق',
    },
    {
      'title': 'بناء عادات النجاح',
      'category': 'تطوير ذاتي',
      'duration': '6 دقائق',
    },
    {
      'title': 'فن التواصل الفعّال',
      'category': 'علاقات',
      'duration': '7 دقائق',
    },
    {
      'title': 'القيادة بالتأثير',
      'category': 'قيادة',
      'duration': '10 دقائق',
    },
    {
      'title': 'إدارة الضغوط اليومية',
      'category': 'صحة نفسية',
      'duration': '5 دقائق',
    },
    {
      'title': 'تطوير الذكاء العاطفي',
      'category': 'تطوير ذاتي',
      'duration': '9 دقائق',
    },
    {
      'title': 'تحقيق التوازن في الحياة',
      'category': 'صحة نفسية',
      'duration': '6 دقائق',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[index % _items.length];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['category']!,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        Text(
                          ' ${item['duration']}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.bookmark_border_outlined,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
