import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: const Column(
              children: [
                Text('إجمالي الأرباح', style: TextStyle(color: Colors.white70, fontSize: 14)),
                SizedBox(height: 8),
                Text('12,450 ر.س', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _EarningsStat(label: 'هذا الشهر', value: '3,200 ر.س'),
                    _EarningsStat(label: 'هذا الأسبوع', value: '850 ر.س'),
                    _EarningsStat(label: 'اليوم', value: '150 ر.س'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('آخر المعاملات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._buildTransactions(),
        ],
      ),
    );
  }

  List<Widget> _buildTransactions() {
    final transactions = [
      {'name': 'أحمد محمد', 'date': 'اليوم - 10:00 ص', 'type': 'فيديو', 'amount': '+300'},
      {'name': 'سارة علي', 'date': 'أمس - 2:00 م', 'type': 'دردشة', 'amount': '+150'},
      {'name': 'خالد أحمد', 'date': 'أمس - 4:00 م', 'type': 'صوتي', 'amount': '+200'},
      {'name': 'نورة سالم', 'date': 'الخميس', 'type': 'فيديو', 'amount': '+300'},
    ];
    return transactions.map((t) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.successColor.withOpacity(0.1), child: const Icon(Icons.arrow_downward, color: AppTheme.successColor)),
        title: Text(t['name']!),
        subtitle: Text('${t['date']} • ${t['type']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: Text(t['amount']!, style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    )).toList();
  }
}

class _EarningsStat extends StatelessWidget {
  final String label;
  final String value;
  const _EarningsStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}
