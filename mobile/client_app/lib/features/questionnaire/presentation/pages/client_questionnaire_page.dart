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
  bool _notSubmitted = false;

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
          _notSubmitted = responses.isEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('استبيان ${widget.clientName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notSubmitted
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 72,
                          color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('لم يملأ العميل الاستبيان بعد',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _responses.length,
                  itemBuilder: (_, i) {
                    final r = _responses[i];
                    final type = r['question_type'] as String? ?? 'text';
                    final answer = r['answer'] as String? ?? '—';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
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
                          Text(
                            r['question_text'] as String? ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          if (type == 'rating')
                            Row(
                              children: List.generate(5, (s) {
                                final selected =
                                    int.tryParse(answer) != null &&
                                        (s + 1) <= int.parse(answer);
                                return Icon(
                                  Icons.star,
                                  size: 24,
                                  color: selected
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                );
                              }),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(answer,
                                  style: const TextStyle(
                                      fontSize: 15, height: 1.5)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
