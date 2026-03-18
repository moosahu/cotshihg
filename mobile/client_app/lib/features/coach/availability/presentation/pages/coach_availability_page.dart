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
  static const List<String> _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

  // day_of_week → list of {start, end}
  final Map<int, List<Map<String, String>>> _schedule = {};
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
      final map = <int, List<Map<String, String>>>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final day = m['day_of_week'] as int;
        // start_time/end_time may come as "09:00:00", trim to "09:00"
        final start = (m['start_time'] as String).substring(0, 5);
        final end = (m['end_time'] as String).substring(0, 5);
        map.putIfAbsent(day, () => []).add({'start': start, 'end': end});
      }
      if (mounted) setState(() { _schedule
        ..clear()
        ..addAll(map);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final slots = <Map<String, dynamic>>[];
      _schedule.forEach((day, times) {
        for (final t in times) {
          slots.add({'day_of_week': day, 'start_time': t['start'], 'end_time': t['end']});
        }
      });
      await getIt<ApiClient>().updateAvailability(slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الجدول'), backgroundColor: AppTheme.successColor),
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

  Future<void> _addSlot(int dayIndex) async {
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'وقت البداية',
    );
    if (start == null || !mounted) return;
    TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 2, minute: 0),
      helpText: 'وقت النهاية',
    );
    if (end == null) return;
    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    setState(() {
      _schedule.putIfAbsent(dayIndex, () => []).add({'start': startStr, 'end': endStr});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('جدول التوفر'),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              itemBuilder: (_, dayIndex) {
                final hasSlots = _schedule.containsKey(dayIndex) && _schedule[dayIndex]!.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: hasSlots ? AppTheme.primaryColor : AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${dayIndex + 1}',
                            style: TextStyle(color: hasSlots ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    title: Text(_days[dayIndex], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      hasSlots ? '${_schedule[dayIndex]!.length} فترة متاحة' : 'غير متاح',
                      style: TextStyle(color: hasSlots ? AppTheme.successColor : AppTheme.textSecondary, fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (hasSlots)
                              ...List.from(_schedule[dayIndex]!).map((slot) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text('${slot['start']} - ${slot['end']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
                                      onPressed: () => setState(() {
                                        _schedule[dayIndex]!.remove(slot);
                                        if (_schedule[dayIndex]!.isEmpty) _schedule.remove(dayIndex);
                                      }),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              )),
                            OutlinedButton.icon(
                              onPressed: () => _addSlot(dayIndex),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('إضافة فترة'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: const BorderSide(color: AppTheme.primaryColor)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
