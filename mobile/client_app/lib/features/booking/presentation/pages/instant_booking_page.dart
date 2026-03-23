import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class InstantBookingPage extends StatefulWidget {
  const InstantBookingPage({super.key});
  @override
  State<InstantBookingPage> createState() => _InstantBookingPageState();
}

class _InstantBookingPageState extends State<InstantBookingPage> {
  List<dynamic> _coaches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().getInstantTherapists();
      if (mounted) setState(() {
        _coaches = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBookingSheet(Map<String, dynamic> coach) {
    String selectedType = 'video';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coach['name'] as String? ?? 'كوتش',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppTheme.successColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          const Text('متاح الآن',
                              style: TextStyle(color: AppTheme.successColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('نوع الجلسة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              ...[
                ('chat', 'محادثة نصية', Icons.chat_bubble_outline, 'session_price_chat'),
                ('voice', 'مكالمة صوتية', Icons.phone_outlined, 'session_price_voice'),
                ('video', 'مكالمة فيديو', Icons.videocam_outlined, 'session_price_video'),
              ].map((e) {
                final price = (double.tryParse(coach[e.$4]?.toString() ?? '0') ?? 0).toInt();
                final selected = selectedType == e.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setSheetState(() => selectedType = e.$1),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                        border: Border.all(
                            color: selected ? AppTheme.primaryColor : const Color(0xFFE0E0E0),
                            width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(e.$3,
                              color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(e.$2,
                                style: TextStyle(
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          ),
                          Text('$price ﷼',
                              style: const TextStyle(
                                  color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('ابدأ الجلسة الآن', style: TextStyle(fontSize: 16)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _book(coach['id'].toString(), selectedType);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _book(String coachId, String sessionType) async {
    try {
      final res = await getIt<ApiClient>().createInstantBooking(coachId, sessionType);
      final data = res['data'] as Map<String, dynamic>?;
      final bookingId = data?['id']?.toString();
      if (bookingId == null) throw Exception('فشل إنشاء الحجز');

      final price = double.tryParse(data?['price']?.toString() ?? '0') ?? 0;

      // If price > 0 → process payment first
      if (price > 0) {
        final paymentRes = await getIt<ApiClient>().initiatePayment(bookingId);
        final clientSecret = paymentRes['data']?['client_secret'] as String?;
        final publishableKey = paymentRes['data']?['publishable_key'] as String?;
        if (clientSecret == null) throw Exception('فشل إنشاء الدفع');

        if (publishableKey != null && publishableKey.isNotEmpty) {
          Stripe.publishableKey = publishableKey;
          await Stripe.instance.applySettings();
        }

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'كوتشينج',
            style: ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        await getIt<ApiClient>().confirmBookingAfterPayment(bookingId);
      }

      if (mounted) {
        if (sessionType == 'chat') {
          context.go('/chat/$bookingId');
        } else {
          context.go('/video-call/$bookingId', extra: {'sessionType': sessionType});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جلسة فورية'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coaches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flash_off, size: 72,
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('لا يوجد كوتشز متاحون الآن',
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text('حاول مرة أخرى لاحقاً أو احجز موعداً مسبقاً',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: const Text('تحديث'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF7043).withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.flash_on, color: Color(0xFFFF7043)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'هؤلاء الكوتشز متاحون الآن للجلسات الفورية',
                                style: TextStyle(color: Color(0xFFFF7043), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._coaches.map((c) {
                        final coach = c as Map<String, dynamic>;
                        final name = coach['name'] as String? ?? 'كوتش';
                        final specs = coach['specializations'] as List?;
                        final spec = specs != null && specs.isNotEmpty ? specs.first as String : '';
                        final rating = coach['rating'];
                        final minPrice = [
                          double.tryParse(coach['session_price_chat']?.toString() ?? '0') ?? 0,
                          double.tryParse(coach['session_price_voice']?.toString() ?? '0') ?? 0,
                          double.tryParse(coach['session_price_video']?.toString() ?? '0') ?? 0,
                        ].where((p) => p > 0).fold<double>(0, (a, b) => a == 0 ? b : (b < a ? b : a));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    const CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppTheme.backgroundColor,
                                      child: Icon(Icons.person, size: 36, color: AppTheme.textSecondary),
                                    ),
                                    Positioned(
                                      bottom: 0, left: 0,
                                      child: Container(
                                        width: 14, height: 14,
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 15)),
                                      if (spec.isNotEmpty)
                                        Text(spec,
                                            style: const TextStyle(
                                                color: AppTheme.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (rating != null) ...[
                                            const Icon(Icons.star, size: 13, color: Colors.amber),
                                            Text(' $rating',
                                                style: const TextStyle(fontSize: 12)),
                                            const SizedBox(width: 8),
                                          ],
                                          if (minPrice > 0)
                                            Text('من ${minPrice.toInt()} ﷼',
                                                style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _showBookingSheet(coach),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF7043),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                  child: const Text('احجز'),
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
