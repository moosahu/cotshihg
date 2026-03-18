import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/therapist_repository.dart';

// Events
abstract class TherapistEvent extends Equatable {
  const TherapistEvent();
  @override
  List<Object?> get props => [];
}

class LoadTherapistsEvent extends TherapistEvent {
  final Map<String, dynamic>? filters;
  const LoadTherapistsEvent({this.filters});
  @override
  List<Object?> get props => [filters];
}

class LoadTherapistDetailEvent extends TherapistEvent {
  final String id;
  const LoadTherapistDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class TherapistState extends Equatable {
  const TherapistState();
  @override
  List<Object?> get props => [];
}

class TherapistInitial extends TherapistState {}

class TherapistLoading extends TherapistState {}

class TherapistsLoaded extends TherapistState {
  final List<dynamic> therapists;
  const TherapistsLoaded(this.therapists);
  @override
  List<Object?> get props => [therapists];
}

class TherapistDetailLoaded extends TherapistState {
  final Map<String, dynamic> therapist;
  final List<dynamic> availability;
  const TherapistDetailLoaded({required this.therapist, required this.availability});
  @override
  List<Object?> get props => [therapist, availability];
}

class TherapistError extends TherapistState {
  final String message;
  const TherapistError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class TherapistBloc extends Bloc<TherapistEvent, TherapistState> {
  final TherapistRepository _repo;

  TherapistBloc(this._repo) : super(TherapistInitial()) {
    on<LoadTherapistsEvent>(_onLoad);
    on<LoadTherapistDetailEvent>(_onLoadDetail);
  }

  Future<void> _onLoad(LoadTherapistsEvent e, Emitter<TherapistState> emit) async {
    emit(TherapistLoading());
    try {
      final list = await _repo.getTherapists(filters: e.filters);
      emit(TherapistsLoaded(list));
    } catch (err) {
      emit(TherapistError(err.toString()));
    }
  }

  Future<void> _onLoadDetail(LoadTherapistDetailEvent e, Emitter<TherapistState> emit) async {
    emit(TherapistLoading());
    try {
      final therapist = await _repo.getTherapistById(e.id);
      final availability = await _repo.getAvailability(e.id);
      emit(TherapistDetailLoaded(therapist: therapist, availability: availability));
    } catch (err) {
      emit(TherapistError(err.toString()));
    }
  }
}
