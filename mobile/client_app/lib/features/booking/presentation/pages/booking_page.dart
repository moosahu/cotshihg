import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

String _extractError(dynamic e) {
  if (e is DioException) {
    final msg = e.response?.data?['message'];
    if (msg != null && msg.toString().isNotEmpty) return msg.toString();
  }
  return e.toString();
}

class BookingPage extends StatefulWidget {
  final String therapistId;
  const BookingPage({super.key, required this.therapistId});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _sessionType = 'video';
  bool _loading = false;
  bool _loadingData = true;
  bool _policyAccepted = false;
  Map<String, dynamic>? _therapist;

  // availability: list of {day_of_week, start_time, end_time}
  List<Map<String, dynamic>> _availability = [];

  // Generated slots for next 30 days: Map<dateString, List<String>> where value is list of start_times
  Map<String, List<String>> _slotsByDate = {};
  List<String> _availableDates = []; // sorted date strings "yyyy-MM-dd"

  // Already booked: Set of "yyyy-MM-dd|HH:mm" strings
  Set<String> _bookedSlots = {};

  String? _selectedDate;
  String? _selectedTime;

  static const List<String> _dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const List<String> _monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        getIt<ApiClient>().getTherapistById(widget.therapistId),
        getIt<ApiClient>().getTherapistAvailability(widget.therapistId),
      ]);
      final therapist = results[0]['data'] as Map<String, dynamic>?;
      final avail = (results[1]['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Fetch booked slots separately — don't block availability if it fails
      final booked = <String>{};
      try {
        final bookedRes = await getIt<ApiClient>().getTherapistBookedSlots(widget.therapistId);
        final bookedRaw = (bookedRes['data'] as List?) ?? [];
        for (final slot in bookedRaw) {
          final dt = DateTime.tryParse(slot.toString())?.toLocal();
          if (dt != null) {
            final dateKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            final timeKey = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            booked.add('$dateKey|$timeKey');
          }
        }
      } catch (_) {}

      // Build slots for next 30 days
      final slots = <String, List<String>>{};
      final now = DateTime.now();
      for (int i = 1; i <= 30; i++) {
        final date = now.add(Duration(days: i));
        final dow = date.weekday % 7; // Flutter: Mon=1..Sun=7, convert to 0=Sun..6=Sat
        final matching = avail.where((a) => (a['day_of_week'] as int) == dow).toList();
        if (matching.isNotEmpty) {
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final times = <String>{};
          for (final a in matching) {
            final startRaw = (a['start_time'] as String).substring(0, 5); // "09:00"
            final endRaw = (a['end_time'] as String).substring(0, 5);     // "11:00"
            final sp = startRaw.split(':');
            final ep = endRaw.split(':');
            int sh = int.parse(sp[0]), sm = int.parse(sp[1]);
            final eh = int.parse(ep[0]), em = int.parse(ep[1]);
            // Generate 60-minute slots within range
            while (sh * 60 + sm + 60 <= eh * 60 + em) {
              times.add('${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}');
              sm += 60;
              if (sm >= 60) { sh += sm ~/ 60; sm = sm % 60; }
            }
          }
          if (times.isNotEmpty) slots[dateKey] = times.toList()..sort();
        }
      }

      if (mounted) {
        setState(() {
          _therapist = therapist;
          _availability = avail;
          _slotsByDate = slots;
          _availableDates = slots.keys.toList()..sort();
          _bookedSlots = booked;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  double get _price {
    if (_therapist == null) return 0;
    final prices = {
      'chat': _therapist!['session_price_chat'],
      'voice': _therapist!['session_price_voice'],
      'video': _therapist!['session_price_video'],
    };
    return double.tryParse(prices[_sessionType]?.toString() ?? '0') ?? 0;
  }

  String _formatDate(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final dow = date.weekday % 7;
    return '${_dayNames[dow]}، ${date.day} ${_monthNames[date.month - 1]}';
  }

  String _formatTime(String t) {
    // "09:00" -> "9:00 ص" / "14:00" -> "2:00 م"
    final parts = t.split(':');
    int hour = int.parse(parts[0]);
    final min = parts[1];
    final suffix = hour < 12 ? 'ص' : 'م';
    if (hour == 0) hour = 12;
    else if (hour > 12) hour -= 12;
    return '$hour:$min $suffix';
  }

  Future<void> _confirm() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر الموعد أولاً'), backgroundColor: AppTheme.errorColor));
      return;
    }

    final parts = _selectedDate!.split('-');
    final timeParts = _selectedTime!.split(':');
    final scheduledAt = DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
      int.parse(timeParts[0]), int.parse(timeParts[1]),
    );

    setState(() => _loading = true);
    try {
      // 1. Create booking
      final bookingRes = await getIt<ApiClient>().createBooking({
        'therapist_id': widget.therapistId,
        'session_type': _sessionType,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': 60,
      });
      final bookingId = bookingRes['data']?['id']?.toString();

      // 2. If price > 0, initiate Stripe payment
      if (_price > 0 && bookingId != null) {
        await _processPayment(bookingId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('تم إرسال طلب الحجز بنجاح ✓'),
                  backgroundColor: AppTheme.successColor));
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_extractError(e)), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _processPayment(String bookingId) async {
    // Get PaymentIntent client_secret from backend
    final paymentRes = await getIt<ApiClient>().initiatePayment(bookingId);
    final clientSecret = paymentRes['data']?['client_secret'] as String?;
    final publishableKey = paymentRes['data']?['publishable_key'] as String?;
    if (clientSecret == null) throw Exception('فشل إنشاء الدفع');

    if (publishableKey != null && publishableKey.isNotEmpty) {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
    }

    // Initialize Payment Sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'كوتشينج',
        style: ThemeMode.light,
        billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
          name: CollectionMode.always,
        ),
      ),
    );

    // Present Payment Sheet
    await Stripe.instance.presentPaymentSheet();

    // Auto-confirm booking after successful payment
    await getIt<ApiClient>().confirmBookingAfterPayment(bookingId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الدفع والحجز بنجاح ✓'),
              backgroundColor: AppTheme.successColor));
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachName = _therapist?['name'] as String? ?? 'الكوتش';

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز جلسة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.canPop() ? context.pop() : context.go('/therapists'),
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(coachName),
    );
  }

  Widget _buildBody(String coachName) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coach info
                if (_therapist != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.person, color: Colors.white, size: 22)),
                        const SizedBox(width: 12),
                        Text(coachName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Session type
                const Text('نوع الجلسة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...[
                  ('chat', 'محادثة نصية', Icons.chat_bubble_outline),
                  ('voice', 'مكالمة صوتية', Icons.phone_outlined),
                  ('video', 'مكالمة فيديو', Icons.videocam_outlined),
                ].map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _sessionType = e.$1),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _sessionType == e.$1
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.white,
                            border: Border.all(
                                color: _sessionType == e.$1
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFE0E0E0),
                                width: _sessionType == e.$1 ? 2 : 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(e.$3,
                                  color: _sessionType == e.$1
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.$2,
                                    style: TextStyle(
                                        fontWeight: _sessionType == e.$1
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                              if (_therapist != null)
                                Text(
                                  '${(double.tryParse((_therapist![e.$1 == 'chat' ? 'session_price_chat' : e.$1 == 'voice' ? 'session_price_voice' : 'session_price_video'])?.toString() ?? '0') ?? 0).toInt()} ﷼',
                                  style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )),

                const SizedBox(height: 8),

                // Available dates
                if (_availableDates.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الكوتش لم يحدد مواعيد متاحة بعد',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('اختر اليوم',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableDates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final d = _availableDates[i];
                        final parts = d.split('-');
                        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                        final dow = date.weekday % 7;
                        final selected = _selectedDate == d;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedDate = d;
                            _selectedTime = null;
                          }),
                          child: Container(
                            width: 64,
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primaryColor : Colors.white,
                              border: Border.all(
                                  color: selected ? AppTheme.primaryColor : const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_dayNames[dow].substring(0, _dayNames[dow].length > 3 ? 3 : _dayNames[dow].length),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: selected ? Colors.white70 : AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text('${date.day}',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: selected ? Colors.white : AppTheme.textPrimary)),
                                Text(_monthNames[date.month - 1].substring(0, 3),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: selected ? Colors.white70 : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (_selectedDate != null) ...[
                    const SizedBox(height: 16),
                    Text('المواعيد المتاحة — ${_formatDate(_selectedDate!)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_slotsByDate[_selectedDate!] ?? []).map((t) {
                        final slotKey = '$_selectedDate|$t';
                        final isBooked = _bookedSlots.contains(slotKey);
                        final selected = _selectedTime == t;
                        return GestureDetector(
                          onTap: isBooked ? null : () => setState(() => _selectedTime = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? const Color(0xFFF0F0F0)
                                  : selected
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                              border: Border.all(
                                  color: isBooked
                                      ? const Color(0xFFDDDDDD)
                                      : selected
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_formatTime(t),
                                    style: TextStyle(
                                        color: isBooked
                                            ? AppTheme.textSecondary
                                            : selected
                                                ? Colors.white
                                                : AppTheme.textPrimary,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                        decoration: isBooked ? TextDecoration.lineThrough : null)),
                                if (isBooked) ...[
                                  const SizedBox(width: 4),
                                  const Text('محجوز',
                                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom: cancellation policy + price + confirm button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_price > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سعر الجلسة', style: TextStyle(color: AppTheme.textSecondary)),
                      Text('${_price.toInt()} ﷼',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سياسة الإلغاء: يمكن الإلغاء باسترداد كامل قبل 24 ساعة من الجلسة. بعد ذلك لا يمكن الإلغاء.',
                              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _policyAccepted,
                            onChanged: (v) => setState(() => _policyAccepted = v ?? false),
                            activeColor: AppTheme.primaryColor,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Expanded(
                            child: Text(
                              'أوافق على سياسة الإلغاء',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_loading || _availableDates.isEmpty || (_price > 0 && !_policyAccepted)) ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_price > 0 ? 'الدفع والحجز' : 'تأكيد الحجز', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
