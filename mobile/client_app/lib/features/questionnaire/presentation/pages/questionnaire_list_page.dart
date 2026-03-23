import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class QuestionnaireListPage extends StatefulWidget {
  const QuestionnaireListPage({super.key});

  @override
  State<QuestionnaireListPage> createState() => _QuestionnaireListPageState();
}

class _QuestionnaireListPageState extends State<QuestionnaireListPage> {
  List<dynamic> _templates = [];
  bool _loading = true;
  String? _error;

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
      final res = await getIt<ApiClient>().getMyQuestionnaires();
      setState(() {
        _templates = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الاستبيان'),
        content: const Text('هل أنت متأكد من حذف هذا الاستبيان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await getIt<ApiClient>().deleteQuestionnaire(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الاستبيان')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      await getIt<ApiClient>().setDefaultQuestionnaire(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعيين الاستبيان كافتراضي')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('استبياناتي'),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          onPressed: () async {
            await context.push('/coach/questionnaires/new');
            _load();
          },
          child: const Icon(Icons.add),
        ),
        body: _buildBody(),
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
            Text('حدث خطأ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: AppTheme.textSecondary.withOpacity(0.35)),
            const SizedBox(height: 16),
            const Text(
              'لا توجد استبيانات بعد\nاضغط + لإنشاء استبيان',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _templates.length,
        itemBuilder: (_, i) {
          final t = _templates[i] as Map<String, dynamic>;
          final id = t['id']?.toString() ?? '';
          final title = t['title'] as String? ?? 'بدون عنوان';
          final questionsCount = (t['questions'] as List?)?.length ?? t['questions_count'] ?? 0;
          final isDefault = t['is_default'] == true;

          return Dismissible(
            key: Key(id),
            direction: DismissDirection.startToEnd,
            background: Container(
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            confirmDismiss: (_) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف الاستبيان'),
                  content: const Text('هل أنت متأكد من حذف هذا الاستبيان؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              return confirmed ?? false;
            },
            onDismissed: (_) async {
                try {
                  await getIt<ApiClient>().deleteQuestionnaire(id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف الاستبيان')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
                _load();
              },
            child: GestureDetector(
              onLongPress: () => _delete(id),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await context.push(
                      '/coach/questionnaires/new',
                      extra: {'templateId': id, 'existing': t},
                    );
                    _load();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assignment_outlined, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4)),
                                      ),
                                      child: const Text(
                                        'افتراضي',
                                        style: TextStyle(
                                          color: AppTheme.secondaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$questionsCount سؤال',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            isDefault ? Icons.star : Icons.star_border,
                            color: isDefault ? AppTheme.secondaryColor : AppTheme.textSecondary,
                          ),
                          tooltip: isDefault ? 'افتراضي بالفعل' : 'تعيين كافتراضي',
                          onPressed: isDefault ? null : () => _setDefault(id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
