import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class QuestionnaireFillPage extends StatefulWidget {
  final String assignmentId;

  const QuestionnaireFillPage({super.key, required this.assignmentId});

  @override
  State<QuestionnaireFillPage> createState() => _QuestionnaireFillPageState();
}

class _QuestionnaireFillPageState extends State<QuestionnaireFillPage> {
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  Map<String, dynamic>? _assignment;
  List<dynamic> _questions = [];
  final Map<String, dynamic> _answers = {};

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
      final data = res['data'] as Map<String, dynamic>? ?? res;
      setState(() {
        _assignment = data;
        _questions = (data['template']?['questions'] as List?) ??
            (data['questions'] as List?) ??
            [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _allRequiredAnswered {
    for (final q in _questions) {
      final qMap = q as Map<String, dynamic>;
      final isRequired = qMap['required'] != false;
      if (!isRequired) continue;
      final id = qMap['id']?.toString() ?? '';
      if (!_answers.containsKey(id)) return false;
      final ans = _answers[id];
      if (ans == null) return false;
      if (ans is String && ans.trim().isEmpty) return false;
      if (ans is List && (ans as List).isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await getIt<ApiClient>().submitAnswers(widget.assignmentId, _answers);
      setState(() {
        _submitted = true;
        _submitting = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _assignment?['template']?['title'] as String? ??
        _assignment?['title'] as String? ??
        'الاستبيان';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: _buildBody(),
        bottomNavigationBar: (!_loading && !_submitted && _error == null)
            ? _buildBottomBar()
            : null,
      ),
    );
  }

  Widget _buildBody() {
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
            const Text('تعذّر تحميل الاستبيان', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_submitted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: AppTheme.successColor),
            const SizedBox(height: 16),
            const Text(
              'تم إرسال إجاباتك بنجاح',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(
        child: Text('لا توجد أسئلة في هذا الاستبيان', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return Column(
      children: [
        // Progress indicator
        _buildProgressBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (_, i) {
              final q = _questions[i] as Map<String, dynamic>;
              return _QuestionWidget(
                questionNumber: i + 1,
                question: q,
                answer: _answers[q['id']?.toString() ?? ''],
                onChanged: (ans) {
                  setState(() {
                    _answers[q['id']?.toString() ?? ''] = ans;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final answered = _questions.where((q) {
      final id = (q as Map<String, dynamic>)['id']?.toString() ?? '';
      return _answers.containsKey(id) && _answers[id] != null;
    }).length;
    final total = _questions.length;
    final progress = total == 0 ? 0.0 : answered / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم الإجابة على $answered من $total',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_allRequiredAnswered && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('إرسال الإجابات'),
          ),
        ),
      ),
    );
  }
}

// ─── Question Widget ────────────────────────────────────────────────────────

class _QuestionWidget extends StatelessWidget {
  final int questionNumber;
  final Map<String, dynamic> question;
  final dynamic answer;
  final void Function(dynamic) onChanged;

  const _QuestionWidget({
    required this.questionNumber,
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = question['text'] as String? ?? '';
    final type = question['type'] as String? ?? 'text';
    final isRequired = question['required'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '$questionNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: text,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      children: [
                        if (isRequired)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Answer input based on type
            if (type == 'text') _buildTextInput(context),
            if (type == 'rating') _buildRatingInput(context),
            if (type == 'single_choice') _buildSingleChoiceInput(context),
            if (type == 'multi_choice') _buildMultiChoiceInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(BuildContext context) {
    return TextFormField(
      initialValue: answer as String? ?? '',
      decoration: const InputDecoration(hintText: 'اكتب إجابتك هنا...'),
      textDirection: TextDirection.rtl,
      maxLines: 3,
      onChanged: onChanged,
    );
  }

  Widget _buildRatingInput(BuildContext context) {
    final selectedRating = answer as int? ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          icon: Icon(
            star <= selectedRating ? Icons.star : Icons.star_border,
            color: star <= selectedRating ? AppTheme.secondaryColor : AppTheme.textSecondary.withOpacity(0.5),
            size: 36,
          ),
          onPressed: () => onChanged(star),
        );
      }),
    );
  }

  Widget _buildSingleChoiceInput(BuildContext context) {
    final opts = (question['options'] as List?)?.cast<String>() ?? [];
    final selected = answer as String?;
    return Column(
      children: opts.map((opt) {
        return RadioListTile<String>(
          value: opt,
          groupValue: selected,
          onChanged: (v) => onChanged(v),
          title: Text(opt, style: const TextStyle(fontSize: 14)),
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoiceInput(BuildContext context) {
    final opts = (question['options'] as List?)?.cast<String>() ?? [];
    final selected = (answer as List?)?.cast<String>() ?? <String>[];
    return Column(
      children: opts.map((opt) {
        final isChecked = selected.contains(opt);
        return CheckboxListTile(
          value: isChecked,
          onChanged: (checked) {
            final newSelected = List<String>.from(selected);
            if (checked == true) {
              newSelected.add(opt);
            } else {
              newSelected.remove(opt);
            }
            onChanged(newSelected);
          },
          title: Text(opt, style: const TextStyle(fontSize: 14)),
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }
}
