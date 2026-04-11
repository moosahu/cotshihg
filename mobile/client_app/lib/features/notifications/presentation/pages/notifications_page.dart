import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await getIt<ApiClient>().getNotifications();
      if (mounted) setState(() { _notifications = data; _loading = false; });
      // Mark all as read after opening
      getIt<ApiClient>().markAllNotificationsRead().catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'new_booking':       return Icons.calendar_today_rounded;
      case 'booking_confirmed': return Icons.check_circle_rounded;
      case 'booking_cancelled': return Icons.cancel_rounded;
      case 'session_reminder':  return Icons.alarm_rounded;
      case 'session_joined':      return Icons.video_call_rounded;
      case 'new_questionnaire':   return Icons.assignment_rounded;
      default:                    return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'new_booking':         return AppTheme.primaryColor;
      case 'booking_confirmed':   return Colors.green;
      case 'booking_cancelled':   return Colors.red;
      case 'session_reminder':    return Colors.orange;
      case 'session_joined':      return Colors.blue;
      case 'new_questionnaire':   return Colors.purple;
      default:                    return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('لا توجد إشعارات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isRead = n['is_read'] == true;
                      final type = n['type'] as String?;
                      final createdAt = DateTime.tryParse(n['created_at'] ?? '');

                      return Container(
                        color: isRead ? Colors.transparent : AppTheme.primaryColor.withOpacity(0.04),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _colorFor(type).withOpacity(0.12),
                            child: Icon(_iconFor(type), color: _colorFor(type), size: 22),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((n['body'] as String?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    n['body']!,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ),
                              if (createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    timeago.format(createdAt, locale: 'ar'),
                                    style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
