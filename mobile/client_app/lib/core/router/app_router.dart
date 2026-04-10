import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/di/injection.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/announcement_overlay.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/complete_profile_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/therapists/presentation/pages/therapists_list_page.dart';
import '../../features/therapists/presentation/pages/therapist_detail_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/questionnaire/presentation/pages/questionnaire_page.dart';
import '../../features/questionnaire/presentation/pages/client_questionnaire_page.dart';
// TODO: جلسة فورية — معطلة مؤقتاً، أعد الاستيراد عند تفعيل الميزة
// import '../../features/booking/presentation/pages/instant_booking_page.dart';
import '../../features/session/presentation/pages/chat_session_page.dart';
import '../../features/session/presentation/pages/video_call_page.dart';
import '../../features/session/presentation/pages/rating_page.dart';
import '../../features/mood/presentation/pages/mood_tracker_page.dart';
import '../../features/content/presentation/pages/content_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/my_bookings_page.dart';
import '../../features/profile/presentation/pages/my_payments_page.dart';
import '../../features/profile/presentation/pages/privacy_page.dart';
// Coach screens
import '../../features/coach/dashboard/presentation/pages/coach_dashboard_page.dart';
import '../../features/coach/bookings/presentation/pages/coach_bookings_page.dart';
import '../../features/coach/availability/presentation/pages/coach_availability_page.dart';
import '../../features/coach/earnings/presentation/pages/coach_earnings_page.dart';
import '../../features/coach/profile/presentation/pages/coach_profile_page.dart';
// Questionnaire screens
import '../../features/questionnaire/presentation/pages/questionnaire_list_page.dart';
import '../../features/questionnaire/presentation/pages/questionnaire_form_page.dart';
import '../../features/questionnaire/presentation/pages/questionnaire_fill_page.dart';
import '../../features/questionnaire/presentation/pages/questionnaire_responses_page.dart';

class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    routes: [
      // ─── Auth ───
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpPage(
            phone: extra['phone'] as String,
            verificationId: extra['verificationId'] as String,
            autoToken: extra['autoToken'] as String?,
          );
        },
      ),
      GoRoute(path: '/complete-profile', builder: (_, __) => const CompleteProfilePage()),

      // ─── Client Shell ───
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          GoRoute(path: '/therapists', builder: (_, __) => const TherapistsListPage()),
          GoRoute(path: '/mood', builder: (_, __) => const MoodTrackerPage()),
          GoRoute(path: '/content', builder: (_, __) => const ContentPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),

      // ─── Coach Shell ───
      ShellRoute(
        builder: (context, state, child) => CoachShell(child: child),
        routes: [
          GoRoute(path: '/coach/dashboard', builder: (_, __) => const CoachDashboardPage()),
          GoRoute(path: '/coach/bookings', builder: (_, __) => const CoachBookingsPage()),
          GoRoute(path: '/coach/schedule', builder: (_, __) => const CoachAvailabilityPage()),
          GoRoute(path: '/coach/earnings', builder: (_, __) => const CoachEarningsPage()),
          GoRoute(path: '/coach/profile', builder: (_, __) => const CoachProfilePage()),
          GoRoute(path: '/coach/questionnaires', builder: (_, __) => const QuestionnaireListPage()),
        ],
      ),

      // ─── Shared ───
      GoRoute(
        path: '/coach/questionnaires/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return QuestionnaireFormPage(
            templateId: extra?['templateId'] as String?,
            existing: extra?['existing'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/questionnaire/fill/:assignmentId',
        builder: (_, state) => QuestionnaireFillPage(
          assignmentId: state.pathParameters['assignmentId']!,
        ),
      ),
      GoRoute(
        path: '/questionnaire/responses/:assignmentId',
        builder: (_, state) => QuestionnaireResponsesPage(
          assignmentId: state.pathParameters['assignmentId']!,
        ),
      ),
      GoRoute(
        path: '/therapist/:id',
        builder: (_, state) => TherapistDetailPage(therapistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/booking/:therapistId',
        builder: (_, state) => BookingPage(therapistId: state.pathParameters['therapistId']!),
      ),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (_, state) => ChatSessionPage(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/video-call/:bookingId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VideoCallPage(
            bookingId: state.pathParameters['bookingId']!,
            sessionType: extra?['sessionType'] as String? ?? 'video',
          );
        },
      ),
      GoRoute(
        path: '/coach/video/:bookingId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VideoCallPage(
            bookingId: state.pathParameters['bookingId']!,
            sessionType: extra?['sessionType'] as String? ?? 'video',
            isCoach: true,
          );
        },
      ),
      GoRoute(
        path: '/rating/:bookingId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RatingPage(
            bookingId: state.pathParameters['bookingId']!,
            coachName: extra?['coachName'] as String? ?? 'الكوتش',
          );
        },
      ),
      // TODO: جلسة فورية — معطلة مؤقتاً، أعد تفعيل هذا المسار عند الحاجة
      // GoRoute(path: '/instant-booking', builder: (_, __) => const InstantBookingPage()),
      GoRoute(path: '/questionnaire', builder: (_, __) => const QuestionnairePage()),
      GoRoute(
        path: '/coach/client-questionnaire/:clientId',
        builder: (_, state) => ClientQuestionnairePage(
          clientId: state.pathParameters['clientId']!,
          clientName: (state.extra as Map?)?['clientName'] as String? ?? 'العميل',
        ),
      ),
      GoRoute(path: '/my-bookings', builder: (_, __) => const MyBookingsPage()),
      GoRoute(path: '/my-payments', builder: (_, __) => const MyPaymentsPage()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPage()),
    ],
    errorBuilder: (context, state) => const SplashPage(),
  );
}

// ─── Client Bottom Nav ───
class ClientShell extends StatefulWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<String> _routes = ['/home', '/therapists', '/mood', '/content', '/profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission();
      showAnnouncementIfActive(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go(_routes[index]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'الكوتشيز'),
          NavigationDestination(icon: Icon(Icons.mood_outlined), selectedIcon: Icon(Icons.mood), label: 'المزاج'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'المحتوى'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// ─── Coach Bottom Nav ───
class CoachShell extends StatefulWidget {
  final Widget child;
  const CoachShell({super.key, required this.child});
  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<String> _routes = [
    '/coach/dashboard',
    '/coach/bookings',
    '/coach/schedule',
    '/coach/earnings',
    '/coach/questionnaires',
    '/coach/profile',
  ];

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  Timer? _vibrateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRingtone();
    _initSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission();
      showAnnouncementIfActive(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Future<void> _initRingtone() async {
    try {
      await _ringtonePlayer.setAsset('assets/sounds/ringtone.wav');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
    } catch (_) {}
  }

  void _startRinging() {
    _ringtonePlayer.play();
    // Vibrate every second
    _vibrateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  void _stopRinging() {
    _ringtonePlayer.stop();
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
  }

  void _initSocket() {
    final socket = getIt<SocketService>();
    socket.connect();
    socket.onIncomingCall(_onIncomingCall);
  }

  void _onIncomingCall(dynamic data) {
    if (!mounted) return;
    final d = data as Map<String, dynamic>;
    final bookingId = d['booking_id'] as String? ?? '';
    final fromName = d['from_name'] as String? ?? 'عميل';
    final callType = d['call_type'] as String? ?? 'video';
    final isVoice = callType == 'voice';

    _startRinging();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(isVoice ? Icons.phone : Icons.videocam, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('طلب جلسة فورية'),
        ]),
        content: Text(
          '$fromName يطلب ${isVoice ? "مكالمة صوتية" : "مكالمة فيديو"}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopRinging();
              Navigator.pop(context);
            },
            child: const Text('رفض', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _stopRinging();
              Navigator.pop(context);
              context.push('/coach/video/$bookingId',
                  extra: {'sessionType': callType});
            },
            icon: Icon(isVoice ? Icons.phone : Icons.videocam),
            label: const Text('قبول'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRinging();
    _ringtonePlayer.dispose();
    getIt<SocketService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go(_routes[index]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'الحجوزات'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'الجدول'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'الأرباح'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'استبيانات'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// Keep MainShell as alias for backwards compatibility
typedef MainShell = ClientShell;
