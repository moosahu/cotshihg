import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.white,
            title: const Text('كيف حالك اليوم؟'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MoodCheckInCard(),
                const SizedBox(height: 16),
                _UpcomingSessionCard(),
                const SizedBox(height: 16),
                _QuickAccessSection(),
                const SizedBox(height: 16),
                _FeaturedTherapistsSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCheckInCard extends StatelessWidget {
  final List<Map<String, dynamic>> moods = const [
    {'emoji': '😊', 'label': 'سعيد', 'score': 8},
    {'emoji': '😐', 'label': 'محايد', 'score': 5},
    {'emoji': '😔', 'label': 'حزين', 'score': 3},
    {'emoji': '😰', 'label': 'قلق', 'score': 2},
    {'emoji': '😡', 'label': 'غاضب', 'score': 2},
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('كيف مزاجك الآن؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: moods.map((mood) => GestureDetector(
                onTap: () {},
                child: Column(
                  children: [
                    Text(mood['emoji'], style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(mood['label'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.white54, child: Icon(Icons.person, color: Colors.white, size: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('جلستك القادمة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Text('د. سارة الأحمد', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('غداً - 10:00 صباحاً', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => context.go('/chat/booking_id'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
              child: const Text('انضم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.people, 'label': 'المعالجون', 'route': '/therapists', 'color': const Color(0xFF5C6BC0)},
      {'icon': Icons.flash_on, 'label': 'جلسة فورية', 'route': '/therapists?instant=true', 'color': const Color(0xFFFF7043)},
      {'icon': Icons.library_books, 'label': 'المحتوى', 'route': '/content', 'color': const Color(0xFF26A69A)},
      {'icon': Icons.mood, 'label': 'تتبع المزاج', 'route': '/mood', 'color': const Color(0xFFAB47BC)},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      children: items.map((item) => GestureDetector(
        onTap: () => context.go(item['route'] as String),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(item['label'] as String, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      )).toList(),
    );
  }
}

class _FeaturedTherapistsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('المعالجون المميزون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () => context.go('/therapists'), child: const Text('عرض الكل')),
          ],
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) => _TherapistCard(index: index),
          ),
        ),
      ],
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final int index;
  const _TherapistCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(left: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const CircleAvatar(radius: 35, backgroundColor: AppTheme.backgroundColor, child: Icon(Icons.person, size: 40, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              const Text('د. محمد الأحمد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('نفسي إكلينيكي', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' 4.8', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/therapist/$index'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  child: const Text('احجز', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
