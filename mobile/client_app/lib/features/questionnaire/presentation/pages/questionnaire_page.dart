import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class QuestionnairePage extends StatefulWidget {
  /// اختياري: إذا جاء من صفحة الكوتش، نصفّي الأسئلة حسب تخصصه
  final String? specialization;
  const QuestionnairePage({super.key, this.specialization});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  List<Map<String, dynamic>> _questions = [];
  Map<String, String> _answers = {}; // question_id → answer
  bool _loading = true;
  bool _submitting = false;
  bool _alreadySubmitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questionsRes = await getIt<ApiClient>().getQuestionnaireQuestions(
        specialization: widget.specialization,
      );
      final myRes = await getIt<ApiClient>().getMyQuestionnaireResponse();

      final questions = (questionsRes['data'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final myAnswers = (myRes['data'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      final Map<String, String> existing = {};
      for (final r in myAnswers) {
        existing[r['question_id'] as String] = r['answer'] as String? ?? '';
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _answers = existing;
          _alreadySubmitted = existing.isNotEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    // تحقق أن كل الأسئلة لها إجابة
    for (final q in _questions) {
      final id = q['id'] as String;
      if ((_answers[id] ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى الإجابة على جميع الأسئلة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await getIt<ApiClient>().submitQuestionnaire(
        _answers.entries
            .map((e) => {'question_id': e.key, 'answer': e.value})
            .toList(),
      );
      if (mounted) {
        setState(() => _alreadySubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إجاباتك ✓'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاستبيان'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(
                  child: Text('لا توجد أسئلة حالياً',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : Column(
                  children: [
                    if (_alreadySubmitted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.successColor.withOpacity(0.1),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: AppTheme.successColor, size: 18),
                            SizedBox(width: 8),
                            Text('لقد أجبت على الاستبيان مسبقاً — يمكنك تعديل إجاباتك',
                                style: TextStyle(
                                    color: AppTheme.successColor, fontSize: 13)),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) {
                          final q = _questions[i];
                          final id = q['id'] as String;
                          final type = q['question_type'] as String? ?? 'text';
                          final options =
                              (q['options'] as List?)?.cast<String>() ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6)
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        q['question_text'] as String? ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (type == 'text')
                                  TextField(
                                    maxLines: 3,
                                    controller: TextEditingController(
                                        text: _answers[id] ?? '')
                                      ..selection = TextSelection.collapsed(
                                          offset:
                                              (_answers[id] ?? '').length),
                                    onChanged: (v) =>
                                        setState(() => _answers[id] = v),
                                    decoration: InputDecoration(
                                      hintText: 'اكتب إجابتك هنا...',
                                      filled: true,
                                      fillColor: AppTheme.backgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  )
                                else if (type == 'rating')
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(
                                      5,
                                      (r) => GestureDetector(
                                        onTap: () => setState(
                                            () => _answers[id] = '${r + 1}'),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _answers[id] == '${r + 1}'
                                                ? AppTheme.primaryColor
                                                : AppTheme.backgroundColor,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color:
                                                  _answers[id] == '${r + 1}'
                                                      ? AppTheme.primaryColor
                                                      : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text('${r + 1}',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _answers[id] == '${r + 1}'
                                                            ? Colors.white
                                                            : AppTheme
                                                                .textPrimary)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (type == 'choice')
                                  Column(
                                    children: options
                                        .map((opt) => GestureDetector(
                                              onTap: () => setState(
                                                  () => _answers[id] = opt),
                                              child: Container(
                                                width: double.infinity,
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: _answers[id] == opt
                                                      ? AppTheme.primaryColor
                                                          .withOpacity(0.1)
                                                      : AppTheme.backgroundColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: _answers[id] == opt
                                                        ? AppTheme.primaryColor
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                                child: Text(opt,
                                                    style: TextStyle(
                                                        color:
                                                            _answers[id] == opt
                                                                ? AppTheme
                                                                    .primaryColor
                                                                : AppTheme
                                                                    .textPrimary,
                                                        fontWeight:
                                                            _answers[id] == opt
                                                                ? FontWeight.bold
                                                                : FontWeight
                                                                    .normal)),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _alreadySubmitted
                                      ? 'تحديث الإجابات'
                                      : 'حفظ الإجابات',
                                  style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
