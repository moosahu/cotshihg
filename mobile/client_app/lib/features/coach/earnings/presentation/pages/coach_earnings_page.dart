import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_client.dart';
import 'package:coaching_client/core/widgets/riyal_text.dart';

class CoachEarningsPage extends StatefulWidget {
  const CoachEarningsPage({super.key});
  @override
  State<CoachEarningsPage> createState() => _CoachEarningsPageState();
}

class _CoachEarningsPageState extends State<CoachEarningsPage> {
  Map<String, dynamic> _earnings = {};
  List<dynamic> _payoutRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        getIt<ApiClient>().getCoachEarnings(),
        getIt<ApiClient>().getMyPayoutRequests(),
      ]);
      setState(() {
        _earnings = (results[0]['data'] as Map<String, dynamic>?) ?? {};
        _payoutRequests = (results[1]['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _requestPayout() {
    final total = double.tryParse(_earnings['total_net']?.toString() ?? '0') ?? 0;
    final pendingAmt = double.tryParse(_earnings['pending_payout']?.toString() ?? '0') ?? 0;
    final available = total - pendingAmt;
    final availableStr = available.toStringAsFixed(0);

    if (available < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الحد الأدنى للسحب 100 ر.س'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Check if there's a pending request
    final hasPending = _payoutRequests.any((r) => r['status'] == 'pending');
    if (hasPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لديك طلب سحب قيد المراجعة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final amtCtrl = TextEditingController(text: availableStr.split('.')[0]);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('طلب سحب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('الرصيد المتاح: ${available.toStringAsFixed(0)} ر.س',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              const Text('سيتم التحويل خلال 1-3 أيام عمل إلى الـ IBAN المسجل',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amtCtrl.text.trim()) ?? 0;
                    Navigator.pop(ctx);
                    try {
                      await getIt<ApiClient>().requestPayout(amount);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال طلب السحب'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                        _load();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
                        );
                      }
                    }
                  },
                  child: const Text('إرسال الطلب'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_earnings['total_net']?.toString() ?? '0') ?? 0;
    final pending = double.tryParse(_earnings['pending_payout']?.toString() ?? '0') ?? 0;
    final available = total - pending;
    final transactions = (_earnings['transactions'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('الأرباح')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Total card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        const Text('إجمالي الأرباح', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        RiyalText('${total.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Available + pending row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text('متاح للسحب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              RiyalText('${available.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppTheme.successColor, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text('طلبات معلقة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              RiyalText('${pending.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Withdraw button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: available >= 100 ? _requestPayout : null,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('طلب سحب'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (available < 100)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('الحد الأدنى للسحب 100 ر.س',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                    ),
                  // Payout requests history
                  if (_payoutRequests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('طلبات السحب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._payoutRequests.map((r) {
                      final status = r['status'] as String? ?? '';
                      final isPaid = status == 'paid';
                      final isPending = status == 'pending';
                      final amount = r['amount']?.toString() ?? '0';
                      final date = r['requested_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)?.toLocal().toString().substring(0, 10) ?? date
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPaid
                                ? AppTheme.successColor.withOpacity(0.1)
                                : isPending
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            child: Icon(
                              isPaid ? Icons.check_circle_outline : isPending ? Icons.pending_outlined : Icons.cancel_outlined,
                              color: isPaid ? AppTheme.successColor : isPending ? Colors.orange : Colors.grey,
                            ),
                          ),
                          title: RiyalText(amount,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : isPending
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPaid ? 'تم التحويل' : isPending ? 'قيد المراجعة' : 'مرفوض',
                              style: TextStyle(
                                color: isPaid ? AppTheme.successColor : isPending ? Colors.orange : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  // Transactions
                  const SizedBox(height: 20),
                  const Text('آخر المعاملات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد معاملات بعد', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    ...transactions.map((t) {
                      final coachAmt = t['coach_amount']?.toString() ?? t['amount']?.toString() ?? '0';
                      final date = t['created_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)?.toLocal().toString().substring(0, 10) ?? date
                          : '';
                      final payoutStatus = t['payout_status'] as String? ?? 'pending';
                      final isPaidOut = payoutStatus == 'paid';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.successColor.withOpacity(0.1),
                            child: const Icon(Icons.arrow_downward, color: AppTheme.successColor),
                          ),
                          title: Text(t['client_name'] as String? ?? '—'),
                          subtitle: Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RiyalText('+$coachAmt',
                                  style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(isPaidOut ? 'محوَّل' : 'مستحق',
                                  style: TextStyle(
                                    color: isPaidOut ? AppTheme.textSecondary : Colors.orange,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
