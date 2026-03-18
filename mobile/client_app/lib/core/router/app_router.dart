import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/complete_profile_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/therapists/presentation/pages/therapists_list_page.dart';
import '../../features/therapists/presentation/pages/therapist_detail_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/session/presentation/pages/chat_session_page.dart';
import '../../features/session/presentation/pages/video_call_page.dart';
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

class AppRouter {
  static final router = GoRouter(
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
        ],
      ),

      // ─── Shared ───
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
        builder: (_, state) => VideoCallPage(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/coach/video/:bookingId',
        builder: (_, state) => VideoCallPage(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(path: '/my-bookings', builder: (_, __) => const MyBookingsPage()),
      GoRoute(path: '/my-payments', builder: (_, __) => const MyPaymentsPage()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPage()),
    ],
  );
}

// ─── Client Bottom Nav ───
class ClientShell extends StatefulWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _selectedIndex = 0;
  final List<String> _routes = ['/home', '/therapists', '/mood', '/content', '/profile'];

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
          NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'الكوتشز'),
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

class _CoachShellState extends State<CoachShell> {
  int _selectedIndex = 0;
  final List<String> _routes = [
    '/coach/dashboard',
    '/coach/bookings',
    '/coach/schedule',
    '/coach/earnings',
    '/coach/profile',
  ];

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
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// Keep MainShell as alias for backwards compatibility
typedef MainShell = ClientShell;
