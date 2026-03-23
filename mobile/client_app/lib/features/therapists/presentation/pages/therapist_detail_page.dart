import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/therapist_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';

class TherapistDetailPage extends StatelessWidget {
  final String therapistId;
  const TherapistDetailPage({super.key, required this.therapistId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TherapistBloc>()
        ..add(LoadTherapistDetailEvent(therapistId)),
      child: BlocBuilder<TherapistBloc, TherapistState>(
        builder: (context, state) {
          if (state is TherapistLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is TherapistError) {
            return Scaffold(body: Center(child: Text(state.message)));
          }
          if (state is! TherapistDetailLoaded) {
            return const Scaffold(body: SizedBox());
          }

          final t = state.therapist;
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: t['avatar_url'] != null
                                ? NetworkImage(t['avatar_url'])
                                : null,
                            child: t['avatar_url'] == null
                                ? const Icon(Icons.person,
                                    size: 48, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (t['specializations'] as List?)?.join(' • ') ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            icon: Icons.star,
                            value: '${t['rating'] ?? 0}',
                            label: 'التقييم',
                          ),
                          _StatItem(
                            icon: Icons.people,
                            value: '${t['total_sessions'] ?? 0}',
                            label: 'جلسة',
                          ),
                          _StatItem(
                            icon: Icons.workspace_premium,
                            value: '${t['years_experience'] ?? 0}',
                            label: 'سنة خبرة',
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      // Bio
                      if (t['bio'] != null) ...[
                        const Text(
                          'نبذة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t['bio'],
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Session types & prices
                      const Text(
                        'أسعار الجلسات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SessionTypeCard(
                        type: 'chat',
                        label: 'نصي',
                        icon: Icons.chat_bubble_outline,
                        price: '${t['session_price_chat'] ?? 0}',
                      ),
                      _SessionTypeCard(
                        type: 'voice',
                        label: 'صوتي',
                        icon: Icons.mic_outlined,
                        price: '${t['session_price_voice'] ?? 0}',
                      ),
                      _SessionTypeCard(
                        type: 'video',
                        label: 'فيديو',
                        icon: Icons.videocam_outlined,
                        price: '${t['session_price_video'] ?? 0}',
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/booking/$therapistId'),
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('احجز جلسة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _SessionTypeCard extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final String price;

  const _SessionTypeCard({
    required this.type,
    required this.label,
    required this.icon,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            '$price ﷼',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
