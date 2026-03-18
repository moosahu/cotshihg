import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});
  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
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
      final list = (res['data'] as List?) ?? [];
      double total = 0;
      for (final t in list) {
        final amount = (t as Map<String, dynamic>)['amount'];
        if (t['status'] == 'completed' && amount != null) {
          total += (amount as num).toDouble();
        }
      }
      if (mounted) setState(() {
        _transactions = list;
        _total = total;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      const Text('إجمالي الأرباح',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('${_total.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('آخر المعاملات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (_transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('لا توجد معاملات بعد',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ..._transactions.map((t) {
                    final tx = t as Map<String, dynamic>;
                    final name = tx['client_name'] as String? ?? 'عميل';
                    final amount = tx['amount'] ?? 0;
                    final date = tx['created_at'] as String?;
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
                        title: Text(name),
                        subtitle: Text(dateStr,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        trailing: Text('+$amount ر.س',
                            style: const TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
