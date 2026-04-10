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
  List<dynamic> _payoutRequests = [];
  double _totalNet = 0;
  double _pendingPayout = 0;
  int _coachRate = 70;
  bool _loading = true;
  bool _requesting = false;
  static const double _minPayout = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        getIt<ApiClient>().getCoachEarnings(),
        getIt<ApiClient>().getPayoutRequests(),
      ]);
      final data = results[0]['data'] as Map<String, dynamic>? ?? {};
      final list = (data['transactions'] as List?) ?? [];
      final payouts = (results[1]['data'] as List?) ?? [];
      if (mounted) setState(() {
        _transactions = list;
        _totalNet = (data['total_net'] as num?)?.toDouble() ?? 0;
        _pendingPayout = (data['pending_payout'] as num?)?.toDouble() ?? 0;
        _coachRate = (data['coach_rate'] as num?)?.toInt() ?? 70;
        _payoutRequests = payouts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    setState(() => _requesting = true);
    try {
      await getIt<ApiClient>().requestPayout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال طلب السحب — سيتم التحويل خلال 1-3 أيام عمل'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 4)));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Widget _buildPayoutSection() {
    final hasPendingRequest = _payoutRequests.any((r) => r['status'] == 'pending');
    final canRequest = _pendingPayout >= _minPayout && !hasPendingRequest;

    return Column(
      children: [
        // Pending amount info
        if (_pendingPayout > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFE65100)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رصيد غير محوَّل',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100))),
                      Text('${_pendingPayout.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFBF360C))),
                    ],
                  ),
                ),
                // Withdraw button
                if (!hasPendingRequest)
                  TextButton(
                    onPressed: canRequest && !_requesting ? _requestPayout : null,
                    child: _requesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            canRequest ? 'طلب سحب' : 'الحد الأدنى ${_minPayout.toInt()} ر.س',
                            style: TextStyle(
                                fontSize: 12,
                                color: canRequest ? AppTheme.primaryColor : AppTheme.textSecondary),
                          ),
                  ),
              ],
            ),
          ),

        // Active payout request badge
        if (hasPendingRequest)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.green, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('طلب سحب قيد المعالجة — سيتم التحويل خلال 1-3 أيام عمل',
                      style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Main earnings card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        const Text('صافي أرباحك',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('${_totalNet.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('نسبتك: $_coachRate% من كل جلسة',
                            style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pending payout + withdraw button
                  _buildPayoutSection(),
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
                      final totalAmount = tx['amount'] ?? 0;
                      final netAmount = tx['coach_amount'] ?? totalAmount;
                      final payoutStatus = tx['payout_status'] as String? ?? 'pending';
                      final paymentMethod = tx['payment_method'] as String? ?? '';
                      final date = tx['created_at'] as String?;
                      final dateStr = date != null
                          ? DateTime.tryParse(date)?.toLocal().toString().substring(0, 10) ?? date
                          : '';

                      final isPaid = payoutStatus == 'paid';
                      final methodIcon = paymentMethod == 'mada'
                          ? Icons.credit_card
                          : paymentMethod == 'apple_pay'
                              ? Icons.apple
                              : Icons.payment;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Icon(methodIcon, color: AppTheme.primaryColor, size: 20),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? AppTheme.successColor.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? 'تم التحويل' : 'في الانتظار',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isPaid ? AppTheme.successColor : Colors.orange,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${double.tryParse(netAmount.toString())?.toStringAsFixed(0) ?? netAmount} ر.س',
                                style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              Text(
                                'من ${double.tryParse(totalAmount.toString())?.toStringAsFixed(0) ?? totalAmount}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
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
