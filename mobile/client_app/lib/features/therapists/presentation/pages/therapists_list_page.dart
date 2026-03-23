import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/therapist_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';

class TherapistsListPage extends StatefulWidget {
  const TherapistsListPage({super.key});

  @override
  State<TherapistsListPage> createState() => _TherapistsListPageState();
}

class _TherapistsListPageState extends State<TherapistsListPage> {
  String _selectedSpecialization = 'الكل';
  bool _instantOnly = false;
  final _searchController = TextEditingController();

  final List<String> _specializations = [
    'الكل',
    'تطوير ذات',
    'قيادة',
    'إنتاجية',
    'علاقات',
    'مهني',
    'أسري',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TherapistBloc>()..add(const LoadTherapistsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الكوتشز'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن كوتش...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _specializations.length + 1,
                itemBuilder: (_, i) {
                  if (i == _specializations.length) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: const Text('فوري فقط'),
                        selected: _instantOnly,
                        onSelected: (v) => setState(() => _instantOnly = v),
                        selectedColor:
                            AppTheme.accentColor.withOpacity(0.2),
                        checkmarkColor: AppTheme.accentColor,
                      ),
                    );
                  }
                  final spec = _specializations[i];
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(spec),
                      selected: _selectedSpecialization == spec,
                      onSelected: (_) =>
                          setState(() => _selectedSpecialization = spec),
                      selectedColor:
                          AppTheme.primaryColor.withOpacity(0.15),
                      checkmarkColor: AppTheme.primaryColor,
                    ),
                  );
                },
              ),
            ),
            // List
            Expanded(
              child: BlocBuilder<TherapistBloc, TherapistState>(
                builder: (context, state) {
                  if (state is TherapistLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is TherapistError) {
                    return Center(child: Text(state.message));
                  }

                  final therapists =
                      state is TherapistsLoaded ? state.therapists : [];

                  if (therapists.isEmpty) {
                    return const Center(child: _EmptyTherapists());
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: therapists.length,
                    itemBuilder: (_, i) => _TherapistCard(
                      therapist: therapists[i] as Map<String, dynamic>,
                      onTap: () =>
                          context.push('/therapist/${therapists[i]['id']}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTherapists extends StatelessWidget {
  const _EmptyTherapists();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.people_outline,
          size: 80,
          color: AppTheme.textSecondary.withOpacity(0.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'لا يوجد كوتشز متاحون',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ],
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final Map<String, dynamic> therapist;
  final VoidCallback onTap;

  const _TherapistCard({required this.therapist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage: therapist['avatar_url'] != null
                    ? NetworkImage(therapist['avatar_url'])
                    : null,
                child: therapist['avatar_url'] == null
                    ? const Icon(Icons.person,
                        size: 32, color: AppTheme.primaryColor)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            therapist['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (therapist['is_available_instant'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.successColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'متاح الآن',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (therapist['specializations'] as List?)?.join(' • ') ??
                          '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        Text(
                          ' ${therapist['rating'] ?? '0.0'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time,
                            size: 14, color: AppTheme.textSecondary),
                        Text(
                          ' ${therapist['years_experience'] ?? 0} سنوات',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${therapist['session_price_video'] ?? '--'} ر.س',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
