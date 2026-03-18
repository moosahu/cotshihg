import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  String _selected = 'الكل';
  final List<String> _categories = ['الكل', 'تطوير ذاتي', 'إنتاجية', 'علاقات', 'قيادة', 'صحة نفسية'];
  List<dynamic> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getContent();
      if (mounted) setState(() {
        _all = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered => _selected == 'الكل'
      ? _all
      : _all.where((c) => (c as Map)['category'] == _selected).toList();

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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('لا يوجد محتوى في هذا القسم',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _ContentCard(item: _filtered[i] as Map<String, dynamic>),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ContentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? item['title_ar'] as String? ?? '';
    final category = item['category'] as String? ?? '';
    final duration = item['duration'] as String? ?? '';

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
                width: 80, height: 80,
                decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(category,
                            style: const TextStyle(
                                color: AppTheme.primaryColor, fontSize: 11)),
                      ),
                    if (duration.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 13, color: AppTheme.textSecondary),
                        Text(' $duration',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ]),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.bookmark_border_outlined,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
