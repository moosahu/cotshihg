import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/booking_repository.dart';

// Events
abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class CreateBookingEvent extends BookingEvent {
  final Map<String, dynamic> data;
  const CreateBookingEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class LoadMyBookingsEvent extends BookingEvent {
  final String? status;
  const LoadMyBookingsEvent({this.status});
  @override
  List<Object?> get props => [status];
}

class CancelBookingEvent extends BookingEvent {
  final String bookingId;
  const CancelBookingEvent({required this.bookingId});
  @override
  List<Object?> get props => [bookingId];
}

// States
abstract class BookingState extends Equatable {
  const BookingState();
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class BookingCreated extends BookingState {
  final Map<String, dynamic> booking;
  const BookingCreated(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingsLoaded extends BookingState {
  final List<dynamic> bookings;
  const BookingsLoaded(this.bookings);
  @override
  List<Object?> get props => [bookings];
}

class BookingError extends BookingState {
  final String message;
  const BookingError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository _repo;

  BookingBloc(this._repo) : super(BookingInitial()) {
    on<CreateBookingEvent>(_onCreate);
    on<LoadMyBookingsEvent>(_onLoad);
    on<CancelBookingEvent>(_onCancel);
  }

  Future<void> _onCreate(CreateBookingEvent e, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final booking = await _repo.createBooking(e.data);
      emit(BookingCreated(booking));
    } catch (err) {
      emit(BookingError(err.toString()));
    }
  }

  Future<void> _onLoad(LoadMyBookingsEvent e, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final list = await _repo.getMyBookings(status: e.status);
      emit(BookingsLoaded(list));
    } catch (err) {
      emit(BookingError(err.toString()));
    }
  }

  Future<void> _onCancel(CancelBookingEvent e, Emitter<BookingState> emit) async {
    try {
      await _repo.cancelBooking(e.bookingId);
      emit(const BookingsLoaded([]));
    } catch (err) {
      emit(BookingError(err.toString()));
    }
  }
}
