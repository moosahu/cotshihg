import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class CoachAvailabilityPage extends StatefulWidget {
  const CoachAvailabilityPage({super.key});
  @override
  State<CoachAvailabilityPage> createState() => _CoachAvailabilityPageState();
}

class _CoachAvailabilityPageState extends State<CoachAvailabilityPage> {
  static const List<String> _dayNames = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];
  static const List<String> _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  // dateKey "yyyy-MM-dd" → list of {start, end}
  final Map<String, List<Map<String, String>>> _schedule = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getMyOwnAvailability();
      final list = (res['data'] as List?) ?? [];
      final map = <String, List<Map<String, String>>>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final specificDate = m['specific_date'];
        if (specificDate != null) {
          final dateKey = specificDate.toString().substring(0, 10);
          final start = (m['start_time'] as String).substring(0, 5);
          final end = (m['end_time'] as String).substring(0, 5);
          map.putIfAbsent(dateKey, () => []).add({'start': start, 'end': end});
        }
      }
      if (mounted) {
        setState(() {
          _schedule..clear()..addAll(map);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final slots = <Map<String, dynamic>>[];
      _schedule.forEach((dateKey, times) {
        final parts = dateKey.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final dow = date.weekday % 7;
        for (final t in times) {
          slots.add({
            'day_of_week': dow,
            'start_time': t['start'],
            'end_time': t['end'],
            'specific_date': dateKey,
          });
        }
      });
      await getIt<ApiClient>().updateAvailability(slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الجدول ✓'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'اختر التاريخ',
    );
    if (picked == null || !mounted) return;
    await _addSlotForDate(picked);
  }

  Future<void> _addSlotForDate(DateTime date) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'وقت البداية',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
      helpText: 'وقت النهاية',
    );
    if (end == null) return;

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    setState(() {
      _schedule.putIfAbsent(dateKey, () => []).add({'start': startStr, 'end': endStr});
    });
  }

  String _formatDate(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final dow = date.weekday % 7;
    return '${_dayNames[dow]}، ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sortedDates = (_schedule.keys.toList()..sort()).where((d) {
      final parts = d.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return !date.isBefore(today);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('المواعيد المتاحة'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDate,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة تاريخ', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : sortedDates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 72, color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('لا توجد مواعيد متاحة',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('اضغط + لإضافة تاريخ محدد',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: sortedDates.length,
                  itemBuilder: (_, i) {
                    final dateKey = sortedDates[i];
                    final slots = _schedule[dateKey]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_today,
                                      size: 16, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatDate(dateKey),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.errorColor, size: 20),
                                  onPressed: () =>
                                      setState(() => _schedule.remove(dateKey)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'حذف هذا التاريخ',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...List.from(slots).map((slot) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 15, color: AppTheme.primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${slot['start']} - ${slot['end']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          slots.remove(slot);
                                          if (slots.isEmpty) _schedule.remove(dateKey);
                                        }),
                                        child: const Icon(Icons.close,
                                            size: 16, color: AppTheme.errorColor),
                                      ),
                                    ],
                                  ),
                                )),
                            TextButton.icon(
                              onPressed: () async {
                                final parts = dateKey.split('-');
                                final date = DateTime(int.parse(parts[0]),
                                    int.parse(parts[1]), int.parse(parts[2]));
                                await _addSlotForDate(date);
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('إضافة فترة أخرى',
                                  style: TextStyle(fontSize: 13)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
