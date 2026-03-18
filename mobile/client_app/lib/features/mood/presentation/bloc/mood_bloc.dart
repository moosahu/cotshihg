import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/mood_repository.dart';

// Events
abstract class MoodEvent extends Equatable {
  const MoodEvent();
  @override
  List<Object?> get props => [];
}

class LogMoodEvent extends MoodEvent {
  final int score;
  final String label;
  final String? note;
  const LogMoodEvent({required this.score, required this.label, this.note});
  @override
  List<Object?> get props => [score, label, note];
}

class LoadMoodHistoryEvent extends MoodEvent {}

// States
abstract class MoodState extends Equatable {
  const MoodState();
  @override
  List<Object?> get props => [];
}

class MoodInitial extends MoodState {}

class MoodLoading extends MoodState {}

class MoodLogged extends MoodState {}

class MoodHistoryLoaded extends MoodState {
  final List<dynamic> history;
  const MoodHistoryLoaded(this.history);
  @override
  List<Object?> get props => [history];
}

class MoodError extends MoodState {
  final String message;
  const MoodError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class MoodBloc extends Bloc<MoodEvent, MoodState> {
  final MoodRepository _repo;

  MoodBloc(this._repo) : super(MoodInitial()) {
    on<LogMoodEvent>(_onLog);
    on<LoadMoodHistoryEvent>(_onLoadHistory);
  }

  Future<void> _onLog(LogMoodEvent e, Emitter<MoodState> emit) async {
    emit(MoodLoading());
    try {
      await _repo.logMood(e.score, e.label, note: e.note);
      emit(MoodLogged());
    } catch (err) {
      emit(MoodError(err.toString()));
    }
  }

  Future<void> _onLoadHistory(LoadMoodHistoryEvent e, Emitter<MoodState> emit) async {
    emit(MoodLoading());
    try {
      final history = await _repo.getHistory();
      emit(MoodHistoryLoaded(history));
    } catch (err) {
      emit(MoodError(err.toString()));
    }
  }
}
