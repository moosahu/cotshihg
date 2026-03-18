import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/mood_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';

class MoodTrackerPage extends StatelessWidget {
  const MoodTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<MoodBloc>()..add(LoadMoodHistoryEvent()),
      child: const _MoodTrackerView(),
    );
  }
}

class _MoodTrackerView extends StatefulWidget {
  const _MoodTrackerView();

  @override
  State<_MoodTrackerView> createState() => _MoodTrackerViewState();
}

class _MoodTrackerViewState extends State<_MoodTrackerView> {
  int? _selectedMoodIndex;
  final _noteController = TextEditingController();

  static const List<Map<String, dynamic>> _moods = [
    {'emoji': '😄', 'label': 'رائع', 'score': 10, 'color': Color(0xFF4CAF50)},
    {'emoji': '😊', 'label': 'سعيد', 'score': 8, 'color': Color(0xFF8BC34A)},
    {'emoji': '😐', 'label': 'محايد', 'score': 5, 'color': Color(0xFFFFC107)},
    {'emoji': '😔', 'label': 'حزين', 'score': 3, 'color': Color(0xFFFF9800)},
    {'emoji': '😰', 'label': 'قلق', 'score': 2, 'color': Color(0xFFF44336)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تتبع المزاج')),
      body: BlocListener<MoodBloc, MoodState>(
        listener: (context, state) {
          if (state is MoodLogged) {
            setState(() {
              _selectedMoodIndex = null;
              _noteController.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل مزاجك')),
            );
            context.read<MoodBloc>().add(LoadMoodHistoryEvent());
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Today check-in card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كيف مزاجك اليوم؟',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_moods.length, (i) {
                        final mood = _moods[i];
                        final selected = _selectedMoodIndex == i;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedMoodIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (mood['color'] as Color).withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? mood['color'] as Color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  mood['emoji'],
                                  style: TextStyle(
                                    fontSize: selected ? 38 : 30,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mood['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: selected
                                        ? mood['color'] as Color
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_selectedMoodIndex != null) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'أضف ملاحظة (اختياري)...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: BlocBuilder<MoodBloc, MoodState>(
                          builder: (context, state) => ElevatedButton(
                            onPressed: state is MoodLoading
                                ? null
                                : () {
                                    final mood =
                                        _moods[_selectedMoodIndex!];
                                    context.read<MoodBloc>().add(
                                          LogMoodEvent(
                                            score: mood['score'] as int,
                                            label: mood['label'] as String,
                                            note: _noteController.text.isEmpty
                                                ? null
                                                : _noteController.text,
                                          ),
                                        );
                                  },
                            child: state is MoodLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Text('سجّل مزاجك'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // History
            const Text(
              'سجل المزاج — آخر 7 أيام',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            BlocBuilder<MoodBloc, MoodState>(
              builder: (context, state) {
                if (state is MoodHistoryLoaded && state.history.isNotEmpty) {
                  return _MoodHistoryList(history: state.history);
                }
                return const _MoodEmptyHistory();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodHistoryList extends StatelessWidget {
  final List<dynamic> history;
  const _MoodHistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: history.take(7).map((log) {
        final entry = log as Map<String, dynamic>;
        final score = (entry['mood_score'] as num?)?.toInt() ?? 5;
        final color = score >= 8
            ? const Color(0xFF4CAF50)
            : score >= 5
                ? const Color(0xFFFFC107)
                : const Color(0xFFF44336);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${score * 10}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['mood_label'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (entry['note'] != null)
                      Text(
                        entry['note'],
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MoodEmptyHistory extends StatelessWidget {
  const _MoodEmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.sentiment_satisfied_alt_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: 8),
          Text(
            'لا يوجد سجل بعد\nابدأ بتسجيل مزاجك اليوم',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
