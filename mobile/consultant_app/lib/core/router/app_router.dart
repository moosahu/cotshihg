import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/session/presentation/pages/chat_session_page.dart';
import '../../features/session/presentation/pages/video_call_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/availability/presentation/pages/availability_page.dart';
import '../../features/earnings/presentation/pages/earnings_page.dart';
import '../di/injection.dart';
import '../services/storage_service.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final token = getIt<StorageService>().getToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      final isLoginPage = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => ConsultantShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage()),
          GoRoute(path: '/availability', builder: (_, __) => const AvailabilityPage()),
          GoRoute(path: '/earnings', builder: (_, __) => const EarningsPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (_, state) => ChatSessionPage(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/video/:bookingId',
        builder: (_, state) => VideoCallPage(bookingId: state.pathParameters['bookingId']!),
      ),
    ],
  );
}

class ConsultantShell extends StatefulWidget {
  final Widget child;
  const ConsultantShell({super.key, required this.child});
  @override
  State<ConsultantShell> createState() => _ConsultantShellState();
}

class _ConsultantShellState extends State<ConsultantShell> {
  int _index = 0;
  final _routes = ['/dashboard', '/bookings', '/availability', '/earnings', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) { setState(() => _index = i); context.go(_routes[i]); },
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
