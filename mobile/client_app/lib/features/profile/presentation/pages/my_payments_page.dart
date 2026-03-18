import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class MyPaymentsPage extends StatefulWidget {
  const MyPaymentsPage({super.key});
  @override
  State<MyPaymentsPage> createState() => _MyPaymentsPageState();
}

class _MyPaymentsPageState extends State<MyPaymentsPage> {
  List<dynamic> _payments = [];
  bool _loading = true;
  double _total = 0;

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
      for (final p in list) {
        final amount = (p as Map<String, dynamic>)['amount'];
        if (amount != null) total += (amount as num).toDouble();
      }
      if (mounted) setState(() {
        _payments = list;
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
      appBar: AppBar(
        title: const Text('سجل المدفوعات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? const Center(
                  child: Text('لا توجد مدفوعات بعد',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        const Text('إجمالي المدفوعات',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('${_total.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    ..._payments.map((p) {
                      final pay = p as Map<String, dynamic>;
                      final name = pay['therapist_name'] as String? ?? 'الكوتش';
                      final amount = pay['amount'] ?? 0;
                      final date = pay['created_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)
                                  ?.toLocal()
                                  .toString()
                                  .substring(0, 10) ??
                              date
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.receipt_outlined,
                                color: AppTheme.primaryColor),
                          ),
                          title: Text(name),
                          subtitle: Text(dateStr,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: Text('$amount ر.س',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
