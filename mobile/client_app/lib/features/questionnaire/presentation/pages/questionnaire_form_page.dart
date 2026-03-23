import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

const _uuid = Uuid();

class QuestionnaireFormPage extends StatefulWidget {
  final String? templateId;
  final Map<String, dynamic>? existing;

  const QuestionnaireFormPage({super.key, this.templateId, this.existing});

  @override
  State<QuestionnaireFormPage> createState() => _QuestionnaireFormPageState();
}

class _QuestionnaireFormPageState extends State<QuestionnaireFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  bool _saving = false;

  // Questions list — each item is a mutable map
  late List<Map<String, dynamic>> _questions;

  bool get _isEditMode => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?['title'] as String? ?? '');
    _descCtrl = TextEditingController(text: existing?['description'] as String? ?? '');

    if (existing != null && existing['questions'] is List) {
      _questions = (existing['questions'] as List).map((q) {
        final qMap = Map<String, dynamic>.from(q as Map);
        // Ensure options is a mutable list of strings
        if (qMap['options'] is List) {
          qMap['options'] = List<String>.from(qMap['options'] as List);
        } else {
          qMap['options'] = <String>[];
        }
        qMap['required'] ??= true;
        return qMap;
      }).toList();
    } else {
      _questions = [];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'id': _uuid.v4(),
        'text': '',
        'type': 'text',
        'options': <String>[],
        'required': true,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _addOption(int qIndex) {
    setState(() {
      (_questions[qIndex]['options'] as List<String>).add('');
    });
  }

  void _removeOption(int qIndex, int oIndex) {
    setState(() {
      (_questions[qIndex]['options'] as List<String>).removeAt(oIndex);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate questions
    for (int i = 0; i < _questions.length; i++) {
      if ((_questions[i]['text'] as String).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('السؤال ${i + 1} لا يحتوي على نص'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      final type = _questions[i]['type'] as String;
      if ((type == 'single_choice' || type == 'multi_choice')) {
        final opts = _questions[i]['options'] as List<String>;
        if (opts.isEmpty || opts.any((o) => o.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('السؤال ${i + 1} يجب أن يحتوي على خيارات غير فارغة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);

    final payload = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'questions': _questions.map((q) {
        final type = q['type'] as String;
        return {
          'id': q['id'],
          'text': (q['text'] as String).trim(),
          'type': type,
          'required': q['required'] ?? true,
          if (type == 'single_choice' || type == 'multi_choice')
            'options': List<String>.from(q['options'] as List),
        };
      }).toList(),
    };

    try {
      if (_isEditMode) {
        await getIt<ApiClient>().updateQuestionnaire(widget.templateId!, payload);
      } else {
        await getIt<ApiClient>().createQuestionnaire(payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'تم تحديث الاستبيان' : 'تم إنشاء الاستبيان'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'تعديل الاستبيان' : 'إنشاء استبيان'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'عنوان الاستبيان',
                  labelText: 'العنوان',
                ),
                textDirection: TextDirection.rtl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  hintText: 'وصف مختصر',
                  labelText: 'الوصف (اختياري)',
                ),
                textDirection: TextDirection.rtl,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Questions section header
              Row(
                children: [
                  const Text(
                    'الأسئلة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_questions.length} سؤال',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question cards
              ..._questions.asMap().entries.map((entry) {
                final i = entry.key;
                return _QuestionCard(
                  key: ValueKey(_questions[i]['id']),
                  index: i,
                  question: _questions[i],
                  onChanged: () => setState(() {}),
                  onDelete: () => _removeQuestion(i),
                  onAddOption: () => _addOption(i),
                  onRemoveOption: (oIndex) => _removeOption(i, oIndex),
                );
              }),

              // Add question button
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('إضافة سؤال'),
              ),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isEditMode ? 'حفظ التعديلات' : 'إنشاء الاستبيان'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question Card Widget ───────────────────────────────────────────────────

class _QuestionCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> question;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onAddOption;
  final void Function(int oIndex) onRemoveOption;

  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.onChanged,
    required this.onDelete,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _textCtrl;
  late List<TextEditingController> _optionCtrls;

  static const Map<String, String> _typeLabels = {
    'text': 'نص حر',
    'rating': 'تقييم 1-5',
    'single_choice': 'اختيار واحد',
    'multi_choice': 'اختيار متعدد',
  };

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.question['text'] as String? ?? '');
    _textCtrl.addListener(() {
      widget.question['text'] = _textCtrl.text;
    });
    _buildOptionControllers();
  }

  void _buildOptionControllers() {
    final opts = widget.question['options'] as List<String>;
    _optionCtrls = opts.map((o) {
      final ctrl = TextEditingController(text: o);
      return ctrl;
    }).toList();
  }

  void _syncOptionControllers() {
    final opts = widget.question['options'] as List<String>;
    // Dispose old controllers beyond current count
    while (_optionCtrls.length > opts.length) {
      _optionCtrls.removeLast().dispose();
    }
    // Add new controllers for new options
    while (_optionCtrls.length < opts.length) {
      final idx = _optionCtrls.length;
      final ctrl = TextEditingController(text: opts[idx]);
      ctrl.addListener(() {
        if (idx < opts.length) opts[idx] = ctrl.text;
      });
      _optionCtrls.add(ctrl);
    }
  }

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final opts = widget.question['options'] as List<String>;
    if (_optionCtrls.length != opts.length) {
      _syncOptionControllers();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.question['type'] as String;
    final opts = widget.question['options'] as List<String>;
    final showOptions = type == 'single_choice' || type == 'multi_choice';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف السؤال',
                  onPressed: widget.onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question text
            TextFormField(
              controller: _textCtrl,
              decoration: InputDecoration(
                hintText: 'نص السؤال ${widget.index + 1}',
              ),
              textDirection: TextDirection.rtl,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Type dropdown
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'نوع السؤال'),
              isExpanded: true,
              items: _typeLabels.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                widget.question['type'] = val;
                if (val != 'single_choice' && val != 'multi_choice') {
                  widget.question['options'] = <String>[];
                } else if ((widget.question['options'] as List).isEmpty) {
                  widget.question['options'] = <String>[''];
                }
                widget.onChanged();
              },
            ),

            // Options (for choice types)
            if (showOptions) ...[
              const SizedBox(height: 12),
              const Text(
                'الخيارات',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ...List.generate(opts.length, (oIdx) {
                if (oIdx >= _optionCtrls.length) _syncOptionControllers();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _optionCtrls[oIdx],
                          decoration: InputDecoration(
                            hintText: 'الخيار ${oIdx + 1}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          textDirection: TextDirection.rtl,
                          onChanged: (v) {
                            opts[oIdx] = v;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: opts.length > 1 ? () => widget.onRemoveOption(oIdx) : null,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  opts.add('');
                  widget.onAddOption();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة خيار'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
