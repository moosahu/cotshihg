import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class QuestionnaireListPage extends StatefulWidget {
  const QuestionnaireListPage({super.key});
  @override
  State<QuestionnaireListPage> createState() => _QuestionnaireListPageState();
}

class _QuestionnaireListPageState extends State<QuestionnaireListPage> {
  List<Map<String, dynamic>> _sets = [];
  bool _loading = true;

  static const Map<String, String> _timingLabels = {
    'before': 'قبل الجلسة',
    'during': 'أثناء الجلسة',
    'after': 'بعد الجلسة',
    'general': 'عام',
  };
  static const Map<String, Color> _timingColors = {
    'before': AppTheme.primaryColor,
    'during': Color(0xFFF5A623),
    'after': Color(0xFF2ECC71),
    'general': AppTheme.textSecondary,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getQuestionnaireSets();
      if (mounted) {
        setState(() {
          _sets = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendToClient(BuildContext context, Map<String, dynamic> set) async {
    // Show dialog to enter booking ID or navigate to bookings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اذهب لصفحة الحجوزات واختر "استبيان" من الحجز المراد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('قاعة الاستبيانات'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _sets.isEmpty
                  ? const Center(
                      child: Text('لا توجد استبيانات بعد',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لإرسال استبيان لعميل، اذهب لصفحة الحجوزات واضغط زر "استبيان" على الحجز',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...['before', 'during', 'after', 'general'].expand((timing) {
                          final group = _sets
                              .where((s) => (s['timing'] ?? 'general') == timing)
                              .toList();
                          if (group.isEmpty) return <Widget>[];
                          final color = _timingColors[timing]!;
                          return [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Row(
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(_timingLabels[timing]!,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                                ],
                              ),
                            ),
                            ...group.map((set) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10)),
                                          child: Icon(Icons.assignment_outlined, color: color),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(set['name'] as String? ?? '',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              if ((set['description'] as String?)?.isNotEmpty == true)
                                                Text(set['description'] as String,
                                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('${set['question_count'] ?? 0} سؤال',
                                                  style: TextStyle(fontSize: 12, color: color)),
                                            ],
                                          ),
                                        ),
                                        if (set['specialization'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10)),
                                            child: Text(set['specialization'] as String,
                                                style: TextStyle(fontSize: 11, color: color)),
                                          ),
                                      ],
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 8),
                          ];
                        }),
                      ],
                    ),
            ),
    );
  }
}
