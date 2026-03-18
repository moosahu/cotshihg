import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';

class CoachEarningsPage extends StatefulWidget {
  const CoachEarningsPage({super.key});
  @override
  State<CoachEarningsPage> createState() => _CoachEarningsPageState();
}

class _CoachEarningsPageState extends State<CoachEarningsPage> {
  List<dynamic> _transactions = [];
  double _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getPaymentHistory();
      final data = (res['data'] as List?) ?? [];
      double total = 0;
      for (final t in data) {
        if (t['status'] == 'completed') total += double.tryParse(t['amount'].toString()) ?? 0;
      }
      setState(() { _transactions = data; _total = total; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('الأرباح')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        const Text('إجمالي الأرباح', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('${_total.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('آخر المعاملات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد معاملات بعد', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    ..._transactions.map((t) {
                      final amount = t['amount']?.toString() ?? '0';
                      final date = t['created_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)?.toLocal().toString().substring(0, 10) ?? date
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.successColor.withOpacity(0.1),
                            child: const Icon(Icons.arrow_downward, color: AppTheme.successColor),
                          ),
                          title: Text(t['user_name'] as String? ?? '—'),
                          subtitle: Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: Text('+$amount ر.س',
                              style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
