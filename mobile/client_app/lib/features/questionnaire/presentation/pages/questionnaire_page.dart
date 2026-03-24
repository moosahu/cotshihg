import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  List<Map<String, dynamic>> _sets = [];
  List<Map<String, dynamic>> _assignments = [];
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

  static const Map<String, IconData> _timingIcons = {
    'before': Icons.assignment_outlined,
    'during': Icons.edit_note_outlined,
    'after': Icons.check_circle_outline,
    'general': Icons.list_alt_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        getIt<ApiClient>().getQuestionnaireSets(),
        getIt<ApiClient>().getMyAssignments(),
      ]);
      if (mounted) {
        setState(() {
          _sets = (results[0]['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _assignments = (results[1]['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSet(Map<String, dynamic> set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QuestionnaireSetFillPage(set: set),
      ),
    ).then((_) => _load()); // refresh counts on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استبياناتي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _sets.isEmpty
                  ? const Center(
                      child: Text('لا توجد استبيانات حالياً',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── استبيانات مرسلة من الكوتش ──
                        if (_assignments.isNotEmpty) ...[
                          const Text('أرسل إليك كوتشك',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                          const SizedBox(height: 8),
                          ..._assignments.map((a) => _AssignmentCard(
                                assignment: a,
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                      builder: (_) =>
                                          _AssignmentFillPage(assignment: a),
                                    ))
                                    .then((_) => _load()),
                              )),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),
                        ],
                        const Text(
                          'قاعة الاستبيانات',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ...['before', 'during', 'after', 'general'].expand((timing) {
                          final group = _sets
                              .where((s) => (s['timing'] as String? ?? 'general') == timing)
                              .toList();
                          if (group.isEmpty) return <Widget>[];
                          return [
                            _TimingHeader(
                              label: _timingLabels[timing]!,
                              color: _timingColors[timing]!,
                              icon: _timingIcons[timing]!,
                            ),
                            const SizedBox(height: 8),
                            ...group.map((set) => _SetCard(
                                  set: set,
                                  timingColor: _timingColors[timing]!,
                                  onTap: () => _openSet(set),
                                )),
                            const SizedBox(height: 20),
                          ];
                        }),
                      ],
                    ),
            ),
    );
  }
}

class _TimingHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _TimingHeader({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _SetCard extends StatelessWidget {
  final Map<String, dynamic> set;
  final Color timingColor;
  final VoidCallback onTap;
  const _SetCard({required this.set, required this.timingColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final questionCount = int.tryParse('${set['question_count']}') ?? 0;
    final answeredCount = int.tryParse('${set['answered_count']}') ?? 0;
    final isComplete = questionCount > 0 && answeredCount >= questionCount;
    final progress = questionCount > 0 ? answeredCount / questionCount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set['name'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if ((set['description'] as String?)?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              set['description'] as String,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 14),
                          SizedBox(width: 4),
                          Text('مكتمل',
                              style: TextStyle(
                                  color: Color(0xFF2ECC71),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.backgroundColor,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(timingColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$answeredCount / $questionCount سؤال',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fill Page ────────────────────────────────────────────────────────────────

class _QuestionnaireSetFillPage extends StatefulWidget {
  final Map<String, dynamic> set;
  const _QuestionnaireSetFillPage({required this.set});

  @override
  State<_QuestionnaireSetFillPage> createState() =>
      _QuestionnaireSetFillPageState();
}

class _QuestionnaireSetFillPageState
    extends State<_QuestionnaireSetFillPage> {
  List<Map<String, dynamic>> _questions = [];
  Map<String, String> _answers = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>()
          .getSetQuestions(widget.set['id'] as String);
      final questions =
          (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final Map<String, String> existing = {};
      for (final q in questions) {
        final ea = q['existing_answer'] as String?;
        if (ea != null && ea.isNotEmpty) {
          existing[q['id'] as String] = ea;
        }
      }
      if (mounted) {
        setState(() {
          _questions = questions;
          _answers = existing;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إجاباتك ✓'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
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
        title: Text(widget.set['name'] as String? ?? 'الاستبيان'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(
                  child: Text('لا توجد أسئلة في هذا الاستبيان',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : Column(
                  children: [
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
                                  _TextAnswer(
                                    initial: _answers[id] ?? '',
                                    onChanged: (v) =>
                                        setState(() => _answers[id] = v),
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
                                        child: _RatingButton(
                                          value: r + 1,
                                          selected: _answers[id] == '${r + 1}',
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
                                              child: _ChoiceOption(
                                                  opt: opt,
                                                  selected:
                                                      _answers[id] == opt),
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
                              : const Text('حفظ الإجابات',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _TextAnswer extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _TextAnswer({required this.initial, required this.onChanged});
  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial)
      ..selection = TextSelection.collapsed(offset: widget.initial.length);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(
    maxLines: 3,
    controller: _ctrl,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      hintText: 'اكتب إجابتك هنا...',
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _RatingButton extends StatelessWidget {
  final int value;
  final bool selected;
  const _RatingButton({required this.value, required this.selected});
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: selected ? AppTheme.primaryColor : AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
    ),
    child: Center(
      child: Text('$value',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppTheme.textPrimary)),
    ),
  );
}

class _ChoiceOption extends StatelessWidget {
  final String opt;
  final bool selected;
  const _ChoiceOption({required this.opt, required this.selected});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: selected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected ? AppTheme.primaryColor : Colors.transparent,
      ),
    ),
    child: Text(opt,
        style: TextStyle(
            color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
  );
}

// ── Assignment Card (sent by coach) ─────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onTap;
  const _AssignmentCard({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDone = assignment['status'] == 'completed';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: isDone ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: isDone
              ? const Color(0xFF2ECC71).withOpacity(0.1)
              : AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(
            isDone ? Icons.check_circle : Icons.assignment_outlined,
            color: isDone ? const Color(0xFF2ECC71) : AppTheme.primaryColor,
          ),
        ),
        title: Text(assignment['set_name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isDone ? 'تم الإجابة ✓' : 'من ${assignment['coach_name'] ?? 'الكوتش'} — في انتظار إجابتك',
          style: TextStyle(
              fontSize: 12,
              color: isDone ? const Color(0xFF2ECC71) : AppTheme.textSecondary),
        ),
        trailing: isDone
            ? null
            : const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
      ),
    );
  }
}

// ── Assignment Fill Page ──────────────────────────────────────────────────────

class _AssignmentFillPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  const _AssignmentFillPage({required this.assignment});
  @override
  State<_AssignmentFillPage> createState() => _AssignmentFillPageState();
}

class _AssignmentFillPageState extends State<_AssignmentFillPage> {
  List<Map<String, dynamic>> _questions = [];
  Map<String, String> _answers = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>()
          .getSetQuestions(widget.assignment['set_id'] as String);
      if (mounted) {
        setState(() {
          _questions = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    for (final q in _questions) {
      if ((_answers[q['id'] as String] ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('يرجى الإجابة على جميع الأسئلة'),
            backgroundColor: AppTheme.errorColor));
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      await getIt<ApiClient>().completeAssignment(
          widget.assignment['id'] as String, _answers);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إرسال إجاباتك للكوتش ✓'),
            backgroundColor: AppTheme.successColor));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment['set_name'] as String? ?? 'استبيان'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length,
                    itemBuilder: (_, i) {
                      final q = _questions[i];
                      final id = q['id'] as String;
                      final type = q['question_type'] as String? ?? 'text';
                      final options = (q['options'] as List?)?.cast<String>() ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                child: Center(child: Text('${i + 1}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(q['question_text'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                            ]),
                            const SizedBox(height: 12),
                            if (type == 'text')
                              _TextAnswer(initial: _answers[id] ?? '', onChanged: (v) => setState(() => _answers[id] = v))
                            else if (type == 'rating')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(5, (r) => GestureDetector(
                                  onTap: () => setState(() => _answers[id] = '${r + 1}'),
                                  child: _RatingButton(value: r + 1, selected: _answers[id] == '${r + 1}'),
                                )),
                              )
                            else if (type == 'choice')
                              Column(children: options.map((opt) => GestureDetector(
                                onTap: () => setState(() => _answers[id] = opt),
                                child: _ChoiceOption(opt: opt, selected: _answers[id] == opt),
                              )).toList()),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('إرسال الإجابات للكوتش', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
