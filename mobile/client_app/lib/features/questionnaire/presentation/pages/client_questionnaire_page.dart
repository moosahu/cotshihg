import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class ClientQuestionnairePage extends StatefulWidget {
  final String clientId;
  final String clientName;
  const ClientQuestionnairePage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientQuestionnairePage> createState() =>
      _ClientQuestionnairePageState();
}

class _ClientQuestionnairePageState extends State<ClientQuestionnairePage> {
  List<Map<String, dynamic>> _responses = [];
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
      final res =
          await getIt<ApiClient>().getClientQuestionnaire(widget.clientId);
      final responses = (res['data']?['responses'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (mounted) {
        setState(() {
          _responses = responses;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('استبيانات ${widget.clientName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_responses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('استبيانات ${widget.clientName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 72, color: AppTheme.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 16),
              const Text('لم يملأ العميل أي استبيان بعد',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Group responses by set
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, String?> setTimings = {};
    for (final r in _responses) {
      final setName = r['set_name'] as String? ?? 'استبيان';
      grouped.putIfAbsent(setName, () => []).add(r);
      setTimings[setName] = r['set_timing'] as String?;
    }

    // Sort groups by timing order
    const timingOrder = ['before', 'during', 'after', 'general'];
    final sortedGroups = grouped.keys.toList()
      ..sort((a, b) {
        final ta = timingOrder.indexOf(setTimings[a] ?? 'general');
        final tb = timingOrder.indexOf(setTimings[b] ?? 'general');
        return ta.compareTo(tb);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('استبيانات ${widget.clientName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: sortedGroups.expand((setName) {
          final items = grouped[setName]!;
          final timing = setTimings[setName] ?? 'general';
          final timingLabel = _timingLabels[timing] ?? timing;
          final timingColor = _timingColors[timing] ?? AppTheme.textSecondary;

          return [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: timingColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: timingColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined, color: timingColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(setName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: timingColor)),
                  ),
                  Text(timingLabel,
                      style: TextStyle(fontSize: 12, color: timingColor)),
                ],
              ),
            ),
            ...items.map((r) => _ResponseCard(response: r)),
            const SizedBox(height: 16),
          ];
        }).toList(),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final Map<String, dynamic> response;
  const _ResponseCard({required this.response});

  @override
  Widget build(BuildContext context) {
    final type = response['question_type'] as String? ?? 'text';
    final answer = response['answer'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response['question_text'] as String? ?? '',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          if (type == 'rating')
            Row(
              children: List.generate(5, (s) {
                final filled = int.tryParse(answer) != null &&
                    (s + 1) <= int.parse(answer);
                return Icon(
                  Icons.star,
                  size: 22,
                  color: filled ? Colors.amber : Colors.grey.shade300,
                );
              }),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(answer,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
        ],
      ),
    );
  }
}
