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

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpPage(phone: state.extra as String),
      ),
      GoRoute(path: '/complete-profile', builder: (_, __) => const CompleteProfilePage()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          GoRoute(path: '/therapists', builder: (_, __) => const TherapistsListPage()),
          GoRoute(path: '/mood', builder: (_, __) => const MoodTrackerPage()),
          GoRoute(path: '/content', builder: (_, __) => const ContentPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
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
        builder: (_, state) => VideoCallPage(bookingId: state.pathParameters['bookingId']!),
      ),
    ],
  );
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
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
          NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'المعالجون'),
          NavigationDestination(icon: Icon(Icons.mood_outlined), selectedIcon: Icon(Icons.mood), label: 'المزاج'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'المحتوى'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
