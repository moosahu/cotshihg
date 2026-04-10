import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import 'package:coaching_client/core/widgets/riyal_text.dart';
import 'package:coaching_client/core/widgets/paymob_payment_page.dart';

String _apiError(dynamic e) {
  if (e is DioException) {
    final msg = e.response?.data?['message'];
    if (msg != null && msg.toString().isNotEmpty) return msg.toString();
  }
  return e.toString();
}

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});
  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جلساتي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'القادمة'),
            Tab(text: 'المعلقة'),
            Tab(text: 'المكتملة'),
            Tab(text: 'الملغية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(status: 'confirmed'),
          _BookingsList(status: 'pending'),
          _BookingsList(status: 'completed'),
          _BookingsList(status: 'cancelled'),
        ],
      ),
    );
  }
}

class _BookingsList extends StatefulWidget {
  final String status;
  const _BookingsList({required this.status});
  @override
  State<_BookingsList> createState() => _BookingsListState();
}

class _BookingsListState extends State<_BookingsList>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await getIt<ApiClient>().getMyBookings(status: widget.status);
      if (mounted) setState(() {
        _bookings = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(String bookingId) async {
    try {
      final paymentRes = await getIt<ApiClient>().initiatePayment(bookingId);
      final clientSecret = paymentRes['data']?['client_secret'] as String?;
      final publicKey = paymentRes['data']?['public_key'] as String?;
      if (clientSecret == null || publicKey == null) throw Exception('فشل إنشاء الدفع');

      if (!mounted) return;
      final result = await Navigator.of(context).push<PaymobResult>(
        MaterialPageRoute(
          builder: (_) => PaymobPaymentPage(clientSecret: clientSecret, publicKey: publicKey),
        ),
      );

      if (result == PaymobResult.success) {
        await getIt<ApiClient>().confirmBookingAfterPayment(bookingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم الدفع والحجز بنجاح ✓'),
            backgroundColor: AppTheme.successColor,
          ));
          _load();
        }
      } else if (result == PaymobResult.failure) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل الدفع، يرجى المحاولة مرة أخرى'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiError(e)), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _cancel(String id, {bool isPaid = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: Text(isPaid
            ? 'هل أنت متأكد من إلغاء هذا الحجز؟\nبما أن الجلسة مدفوعة، سيتم مراجعة استرداد المبلغ من قبل الإدارة.'
            : 'هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await getIt<ApiClient>().cancelBooking(id);
      _load();
      if (mounted && isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم إلغاء الحجز — سيتم التواصل معك بخصوص استرداد المبلغ'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiError(e)), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('لا توجد جلسات', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) {
          final b = _bookings[i] as Map<String, dynamic>;
          final coachName = b['therapist_name'] as String? ?? 'الكوتش';
          final scheduledAt = b['scheduled_at'] as String?;
          final dateStr = scheduledAt != null
              ? DateTime.tryParse(scheduledAt)
                      ?.toLocal()
                      .toString()
                      .substring(0, 16) ??
                  scheduledAt
              : '';
          final sessionType = b['session_type'] as String? ?? '';
          final price = b['price'] ?? 0;
          final id = b['id'].toString();
          final scheduledDateTime = scheduledAt != null ? DateTime.tryParse(scheduledAt)?.toLocal() : null;
          final now = DateTime.now();
          final canStart = scheduledDateTime != null &&
              now.isAfter(scheduledDateTime.subtract(const Duration(minutes: 15))) &&
              now.isBefore(scheduledDateTime.add(const Duration(hours: 2)));
          final hasPrice = (price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0) > 0;
          final isActuallyPaid = (b['payment_status'] as String? ?? '') == 'paid';
          final hoursUntilSession = scheduledDateTime != null ? scheduledDateTime.difference(now).inHours : 999;
          final canCancelPaid = isActuallyPaid && hoursUntilSession >= 24;
          final tooLateToCancel = isActuallyPaid && hoursUntilSession < 24;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: const Icon(Icons.person, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(coachName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(dateStr,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 12)),
                            if (sessionType.isNotEmpty)
                              Text(sessionType,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: RiyalText('$price',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  if (widget.status == 'cancelled') ...[
                    const SizedBox(height: 10),
                    _CancelledInfo(
                      cancelledBy: b['cancelled_by'] as String?,
                      paymentStatus: b['payment_status'] as String?,
                      price: price,
                    ),
                  ] else if (widget.status == 'completed') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text('اكتملت هذه الجلسة',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ] else if (widget.status == 'confirmed') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canStart ? () {
                              if (sessionType == 'chat') {
                                context.go('/chat/$id');
                              } else {
                                context.go('/video-call/$id', extra: {'sessionType': sessionType});
                              }
                            } : null,
                            icon: Icon(
                              sessionType == 'chat' ? Icons.chat_bubble_outline : Icons.videocam_outlined,
                              size: 18,
                            ),
                            label: Text(canStart ? 'ابدأ الجلسة' : 'تبدأ في ${scheduledDateTime != null ? "${scheduledDateTime.hour.toString().padLeft(2,'0')}:${scheduledDateTime.minute.toString().padLeft(2,'0')}" : ""}'),
                          ),
                        ),
                        if (!tooLateToCancel) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _cancel(id, isPaid: canCancelPaid),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: const BorderSide(color: AppTheme.errorColor)),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ],
                    ),
                    if (tooLateToCancel)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'لا يمكن إلغاء الجلسة خلال 24 ساعة من موعدها — تواصل مع الإدارة',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (widget.status == 'pending') ...[
                    const SizedBox(height: 12),
                    if ((b['payment_status'] as String? ?? '') == 'pending' && hasPrice) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _pay(id),
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text('ادفع الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _cancel(id),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor)),
                        child: const Text('إلغاء الجلسة'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CancelledInfo extends StatelessWidget {
  final String? cancelledBy;
  final String? paymentStatus;
  final dynamic price;

  const _CancelledInfo({this.cancelledBy, this.paymentStatus, this.price});

  @override
  Widget build(BuildContext context) {
    final byAdmin = cancelledBy == 'admin';
    final cancelLabel = byAdmin ? 'تم إلغاء هذه الجلسة من قِبَل الإدارة' : 'قمت بإلغاء هذه الجلسة';

    final hasPaid = (price is num ? (price as num).toDouble() : double.tryParse(price?.toString() ?? '0') ?? 0.0) > 0;
    final isRefunded = paymentStatus == 'refunded';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.errorColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(cancelLabel,
                    style: const TextStyle(fontSize: 12, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (hasPaid) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isRefunded ? Colors.purple.withOpacity(0.07) : Colors.orange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isRefunded ? Colors.purple.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isRefunded ? Icons.check_circle_outline : Icons.hourglass_empty,
                  size: 16,
                  color: isRefunded ? Colors.purple : Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRefunded ? 'تم استرداد المبلغ' : 'في انتظار استرداد المبلغ',
                    style: TextStyle(
                        fontSize: 12,
                        color: isRefunded ? Colors.purple : Colors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
