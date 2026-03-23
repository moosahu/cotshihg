import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class QuestionnaireResponsesPage extends StatefulWidget {
  final String assignmentId;

  const QuestionnaireResponsesPage({super.key, required this.assignmentId});

  @override
  State<QuestionnaireResponsesPage> createState() => _QuestionnaireResponsesPageState();
}

class _QuestionnaireResponsesPageState extends State<QuestionnaireResponsesPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _assignment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await getIt<ApiClient>().getAssignment(widget.assignmentId);
      setState(() {
        _assignment = res['data'] as Map<String, dynamic>? ?? res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _assignment?['template']?['title'] as String? ??
        _assignment?['title'] as String? ??
        'إجابات الاستبيان';

    final status = _assignment?['status'] as String? ?? 'pending';
    final isCompleted = status == 'completed';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              if (!_loading && _assignment != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.successColor.withOpacity(0.15)
                        : AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.successColor.withOpacity(0.4)
                          : AppTheme.warningColor.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    isCompleted ? 'مكتمل' : 'معلق',
                    style: TextStyle(
                      color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        body: _buildBody(isCompleted),
      ),
    );
  }

  Widget _buildBody(bool isCompleted) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text('تعذّر تحميل الإجابات', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (!isCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: AppTheme.warningColor.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text(
              'لم يكتمل العميل الاستبيان بعد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم عرض الإجابات هنا بعد اكتمال الاستبيان',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final data = _assignment!;
    final questions = (data['template']?['questions'] as List?) ?? (data['questions'] as List?) ?? [];
    final responses = data['responses'] as Map<String, dynamic>? ??
        data['answers'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final completedAt = data['completed_at'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تم إكمال الاستبيان',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (completedAt != null)
                        Text(
                          _formatDate(completedAt),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Questions and answers
        ...questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value as Map<String, dynamic>;
          final qId = q['id']?.toString() ?? '';
          final qText = q['text'] as String? ?? '';
          final qType = q['type'] as String? ?? 'text';
          final answer = responses[qId];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          qText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Answer
                  if (answer == null)
                    const Text(
                      'لم يُجب على هذا السؤال',
                      style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    )
                  else
                    _buildAnswerWidget(qType, answer),
                ],
              ),
            ),
          );
        }),

        // Completed at footer
        if (completedAt != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'تاريخ الإكمال: ${_formatDate(completedAt)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildAnswerWidget(String type, dynamic answer) {
    switch (type) {
      case 'text':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Text(
            answer?.toString() ?? '',
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
          ),
        );

      case 'rating':
        final rating = answer is int ? answer : int.tryParse(answer.toString()) ?? 0;
        return Row(
          children: [
            ...List.generate(5, (i) {
              final star = i + 1;
              return Icon(
                star <= rating ? Icons.star : Icons.star_border,
                color: star <= rating ? AppTheme.secondaryColor : AppTheme.textSecondary.withOpacity(0.4),
                size: 28,
              );
            }),
            const SizedBox(width: 8),
            Text(
              '$rating / 5',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        );

      case 'single_choice':
        return Row(
          children: [
            const Icon(Icons.radio_button_checked, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                answer?.toString() ?? '',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );

      case 'multi_choice':
        final choices = answer is List ? answer.cast<String>() : <String>[];
        if (choices.isEmpty) {
          return const Text('لا توجد إجابة', style: TextStyle(color: AppTheme.textSecondary));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: choices.map((c) {
            return Chip(
              label: Text(c, style: const TextStyle(fontSize: 13)),
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        );

      default:
        return Text(
          answer?.toString() ?? '',
          style: const TextStyle(color: AppTheme.textPrimary),
        );
    }
  }

  String _formatDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    final local = dt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
