import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import 'package:coaching_client/core/widgets/riyal_text.dart';

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
        final pay = p as Map<String, dynamic>;
        if (pay['status'] == 'paid') {
          total += double.tryParse(pay['amount']?.toString() ?? '0') ?? 0;
        }
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
                        RiyalText('${_total.toStringAsFixed(0)}',
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
                      final status = pay['status'] as String? ?? '';
                      final date = pay['created_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)
                                  ?.toLocal()
                                  .toString()
                                  .substring(0, 10) ??
                              date
                          : '';

                      final isRefunded = status == 'refunded';
                      final isPending = status == 'pending';
                      final isFailed = status == 'failed';

                      final statusLabel = isRefunded ? 'مسترد' : isPending ? 'معلق' : isFailed ? 'فاشل' : 'مدفوع';
                      final statusColor = isRefunded ? Colors.purple : isPending ? Colors.orange : isFailed ? AppTheme.errorColor : AppTheme.successColor;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(
                              isRefunded ? Icons.reply : isFailed ? Icons.error_outline : Icons.receipt_outlined,
                              color: statusColor,
                            ),
                          ),
                          title: Text(name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(statusLabel,
                                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          trailing: RiyalText('$amount',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRefunded ? Colors.purple : AppTheme.primaryColor,
                                  decoration: isRefunded ? TextDecoration.lineThrough : null)),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
