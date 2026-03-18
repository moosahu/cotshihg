import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحجوزات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [Tab(text: 'القادمة'), Tab(text: 'المعلقة'), Tab(text: 'المكتملة')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(status: 'confirmed'),
          _BookingsList(status: 'pending'),
          _BookingsList(status: 'completed'),
        ],
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final String status;
  const _BookingsList({required this.status});

  static const List<Map<String, dynamic>> _mockBookings = [
    {'name': 'أحمد محمد', 'date': 'اليوم - 10:00 ص', 'type': 'video', 'price': 300},
    {'name': 'سارة علي', 'date': 'غداً - 2:00 م', 'type': 'chat', 'price': 150},
    {'name': 'خالد أحمد', 'date': 'الخميس - 4:00 م', 'type': 'voice', 'price': 200},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mockBookings.length,
      itemBuilder: (_, i) {
        final b = _mockBookings[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 24, backgroundColor: AppTheme.primaryColor.withOpacity(0.1), child: const Icon(Icons.person, color: AppTheme.primaryColor)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(b['date'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${b['price']} ر.س', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (status == 'pending') ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('قبول'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('رفض'),
                        ),
                      ),
                    ] else if (status == 'confirmed')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/video/booking_id'),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('بدء الجلسة'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
