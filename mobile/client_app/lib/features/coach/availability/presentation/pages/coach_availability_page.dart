import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class CoachAvailabilityPage extends StatefulWidget {
  const CoachAvailabilityPage({super.key});
  @override
  State<CoachAvailabilityPage> createState() => _CoachAvailabilityPageState();
}

class _CoachAvailabilityPageState extends State<CoachAvailabilityPage> {
  static const List<String> _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

  final Map<int, List<Map<String, String>>> _schedule = {
    0: [{'start': '09:00', 'end': '12:00'}],
    1: [{'start': '10:00', 'end': '14:00'}, {'start': '16:00', 'end': '20:00'}],
    3: [{'start': '09:00', 'end': '13:00'}],
    4: [{'start': '14:00', 'end': '18:00'}],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('جدول التوفر'),
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجدول'))),
            child: const Text('حفظ'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (_, dayIndex) {
          final hasSlots = _schedule.containsKey(dayIndex);
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
                  child: Text('${dayIndex + 1}', style: TextStyle(color: hasSlots ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
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
                        ..._schedule[dayIndex]!.map((slot) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text('${slot['start']} - ${slot['end']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
                                onPressed: () => setState(() => _schedule[dayIndex]!.remove(slot)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        )),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة فترة'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor)),
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
