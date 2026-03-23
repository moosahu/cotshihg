import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Background handler — runs in a separate isolate, must be top-level
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'incoming_call') return;

  // Must re-initialize local notifications in background isolate
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  ));

  final isVoice = (data['call_type'] ?? '') == 'voice';
  await plugin.show(
    0,
    isVoice ? '📞 مكالمة صوتية واردة' : '📹 مكالمة فيديو واردة',
    '${data['from_name'] ?? 'عميل'} يطلب ${isVoice ? "مكالمة صوتية" : "مكالمة فيديو"}',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'incoming_call_channel',
        'مكالمات واردة',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.call,
      ),
    ),
  );
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _callChannelId = 'incoming_call_channel';
  static const _callChannelName = 'مكالمات واردة';

  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Call from main.dart before init() so notification taps can navigate
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> init() async {
    // Register FCM background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Android + iOS init
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel (with ringtone)
    const channel = AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle notification tap when app was terminated (launched from notification)
    final launchDetails = await _localNotif.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null) _handleCallPayload(payload);
    }

    // Handle FCM notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        final bookingId = data['booking_id'] as String? ?? '';
        final callType = data['call_type'] as String? ?? 'video';
        if (bookingId.isNotEmpty && _navigatorKey?.currentContext != null) {
          _navigatorKey!.currentContext!
              .go('/coach/video/$bookingId', extra: {'sessionType': callType});
        }
      }
    });

    // Handle FCM cold start (app killed, opened via notification)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        final bookingId = data['booking_id'] as String? ?? '';
        final callType = data['call_type'] as String? ?? 'video';
        if (bookingId.isNotEmpty) {
          // Delay to let the router initialize
          Future.delayed(const Duration(seconds: 1), () {
            if (_navigatorKey?.currentContext != null) {
              _navigatorKey!.currentContext!
                  .go('/coach/video/$bookingId', extra: {'sessionType': callType});
            }
          });
        }
      }
    });

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        // App is open — socket already handles the dialog
        // No need to show notification
      }
    });
  }

  /// Called when user taps a local notification
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) _handleCallPayload(payload);
  }

  static void _handleCallPayload(String payload) {
    // payload format: "booking_id=xxx&call_type=video"
    final parts = Uri.splitQueryString(payload);
    final bookingId = parts['booking_id'] ?? '';
    final callType = parts['call_type'] ?? 'video';
    if (bookingId.isNotEmpty && _navigatorKey?.currentContext != null) {
      _navigatorKey!.currentContext!
          .go('/coach/video/$bookingId', extra: {'sessionType': callType});
    }
  }

  /// Request notification permission — call this from a widget after app starts
  static Future<void> requestPermission() async {
    // Android 13+ — use flutter_local_notifications native API (most reliable)
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Also request via permission_handler as backup
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    } else if (status.isPermanentlyDenied) {
      // Open app settings so user can enable manually
      await openAppSettings();
    }

    // iOS permission (no-op on Android)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );
  }

  /// Get FCM token to send to backend
  static Future<String?> getFcmToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  /// Show incoming call notification (used in background)
  static Future<void> _showCallNotification({
    required String fromName,
    required String callType,
    required String bookingId,
  }) async {
    final isVoice = callType == 'voice';
    final title = isVoice ? '📞 مكالمة صوتية واردة' : '📹 مكالمة فيديو واردة';
    final body = '$fromName يطلب ${isVoice ? "مكالمة صوتية" : "مكالمة فيديو"}';

    const androidDetails = AndroidNotificationDetails(
      _callChannelId,
      _callChannelName,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.call,
    );

    await _localNotif.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'booking_id=$bookingId&call_type=$callType',
    );
  }
}
