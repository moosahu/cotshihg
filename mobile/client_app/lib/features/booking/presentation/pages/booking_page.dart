import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class BookingPage extends StatefulWidget {
  final String therapistId;
  const BookingPage({super.key, required this.therapistId});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _sessionType = 'video';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  Map<String, dynamic>? _therapist;

  @override
  void initState() {
    super.initState();
    _loadTherapist();
  }

  Future<void> _loadTherapist() async {
    try {
      final res = await getIt<ApiClient>().getTherapistById(widget.therapistId);
      if (mounted) setState(() => _therapist = res['data'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('ar'),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  double get _price {
    if (_therapist == null) return 0;
    final prices = {
      'chat': _therapist!['session_price_chat'],
      'voice': _therapist!['session_price_voice'],
      'video': _therapist!['session_price_video'],
    };
    return ((prices[_sessionType] ?? 0) as num).toDouble();
  }

  Future<void> _confirm() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر التاريخ والوقت أولاً'),
              backgroundColor: AppTheme.errorColor));
      return;
    }

    final scheduledAt = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    setState(() => _loading = true);
    try {
      await getIt<ApiClient>().createBooking({
        'therapist_id': widget.therapistId,
        'session_type': _sessionType,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_minutes': 60,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم إرسال طلب الحجز بنجاح ✓'),
                backgroundColor: AppTheme.successColor));
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachName = _therapist?['name'] as String? ?? 'الكوتش';
    final dateStr = _selectedDate != null
        ? '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}'
        : null;
    final timeStr = _selectedTime != null
        ? _selectedTime!.format(context)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('حجز جلسة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coach name
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
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
                              '${(((_therapist![_sessionType == 'chat' ? 'session_price_chat' : _sessionType == 'voice' ? 'session_price_voice' : 'session_price_video']) ?? 0) as num).toInt()} ر.س',
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
            const Text('الموعد',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Date & time picker
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(dateStr ?? 'اختر التاريخ'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: _selectedDate != null
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(timeStr ?? 'اختر الوقت'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: _selectedTime != null
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300)),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Price summary
            if (_price > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('سعر الجلسة',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    Text('${_price.toInt()} ر.س',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryColor)),
                  ],
                ),
              ),

            ElevatedButton(
              onPressed: _loading ? null : _confirm,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('تأكيد الحجز', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
