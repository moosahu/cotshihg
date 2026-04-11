import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final list = await getIt<ApiClient>().getNotifications();
      final unread = list.where((n) => n['is_read'] == false).length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

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
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () async {
                      await context.push('/notifications');
                      _loadUnreadCount();
                    },
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
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

class _UpcomingSessionCard extends StatefulWidget {
  @override
  State<_UpcomingSessionCard> createState() => _UpcomingSessionCardState();
}

class _UpcomingSessionCardState extends State<_UpcomingSessionCard> {
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Fetch both confirmed and in_progress so client can rejoin active sessions
      final results = await Future.wait([
        getIt<ApiClient>().getMyBookings(status: 'confirmed'),
        getIt<ApiClient>().getMyBookings(status: 'in_progress'),
      ]);
      final list = [
        ...((results[0]['data'] as List?) ?? []),
        ...((results[1]['data'] as List?) ?? []),
      ];
      final now = DateTime.now();
      final upcoming = list.cast<Map<String, dynamic>>().where((b) {
        final sat = b['scheduled_at'] as String?;
        if (sat == null) return false;
        final dt = DateTime.tryParse(sat)?.toLocal();
        return dt != null && dt.isAfter(now.subtract(const Duration(hours: 2)));
      }).toList()
        ..sort((a, b) {
          final da = DateTime.tryParse(a['scheduled_at'] as String? ?? '') ?? DateTime(2100);
          final db = DateTime.tryParse(b['scheduled_at'] as String? ?? '') ?? DateTime(2100);
          return da.compareTo(db);
        });
      if (upcoming.isNotEmpty && mounted) setState(() => _session = upcoming.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const SizedBox.shrink();
    final therapistName = _session!['therapist_name'] as String? ?? 'الكوتش';
    final scheduledAt = _session!['scheduled_at'] as String?;
    final scheduledDateTime = scheduledAt != null ? DateTime.tryParse(scheduledAt)?.toLocal() : null;
    final dateStr = scheduledDateTime != null
        ? scheduledDateTime.toString().substring(0, 16)
        : scheduledAt ?? '';
    final now = DateTime.now();
    final isInProgress = _session!['status'] == 'in_progress';
    final canJoin = isInProgress || (scheduledDateTime != null &&
        now.isAfter(scheduledDateTime.subtract(const Duration(minutes: 15))) &&
        now.isBefore(scheduledDateTime.add(const Duration(hours: 2))));
    final sessionType = _session!['session_type'] as String? ?? 'voice';
    final timeLabel = scheduledDateTime != null
        ? '${scheduledDateTime.hour.toString().padLeft(2, '0')}:${scheduledDateTime.minute.toString().padLeft(2, '0')}'
        : '';
    return Card(
      color: isInProgress ? Colors.green.shade700 : AppTheme.primaryColor,
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
                  Text(
                    isInProgress ? 'جلسة جارية الآن' : 'جلستك القادمة',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(therapistName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canJoin ? () {
                if (sessionType == 'chat') {
                  context.go('/chat/${_session!['id']}');
                } else {
                  context.go('/video-call/${_session!['id']}');
                }
              } : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
              child: Text(isInProgress ? 'انضم مجدداً' : (canJoin ? 'انضم' : timeLabel)),
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
      {'icon': Icons.people, 'label': 'الكوتشيز', 'route': '/therapists', 'color': const Color(0xFF5C6BC0)},
      // TODO: جلسة فورية — معطلة مؤقتاً، يمكن تفعيلها لاحقاً
      // {'icon': Icons.flash_on, 'label': 'جلسة فورية', 'route': '/instant-booking', 'color': const Color(0xFFFF7043)},
      {'icon': Icons.library_books, 'label': 'المحتوى', 'route': '/content', 'color': const Color(0xFF26A69A)},
      {'icon': Icons.mood, 'label': 'تتبع المزاج', 'route': '/mood', 'color': const Color(0xFFAB47BC)},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      children: items.map((item) => GestureDetector(
        onTap: () {
          final route = item['route'] as String;
          // TODO: جلسة فورية — استثناء مؤقت، أعد تفعيله عند إعادة الميزة
          // if (route.startsWith('/instant')) {
          //   context.push(route);
          // } else {
          context.go(route);
          // }
        },
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

class _FeaturedTherapistsSection extends StatefulWidget {
  @override
  State<_FeaturedTherapistsSection> createState() => _FeaturedTherapistsSectionState();
}

class _FeaturedTherapistsSectionState extends State<_FeaturedTherapistsSection> {
  List<dynamic> _therapists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getTherapists();
      setState(() {
        _therapists = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الكوتشيز المميزون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () => context.go('/therapists'), child: const Text('عرض الكل')),
          ],
        ),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_therapists.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا يوجد كوتشيز متاحون بعد', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _therapists.length,
              itemBuilder: (context, i) {
                final t = _therapists[i] as Map<String, dynamic>;
                final name = t['name'] as String? ?? 'كوتش';
                final specs = t['specializations'] as List?;
                final spec = specs != null && specs.isNotEmpty ? specs.first as String : '';
                final rating = t['rating'];
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
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(spec, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              Text(' ${rating ?? '—'}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => context.push('/therapist/${t['id']}'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                              child: const Text('احجز', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
