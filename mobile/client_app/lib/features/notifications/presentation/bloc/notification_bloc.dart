import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class InitNotificationsEvent extends NotificationEvent {}

class NotificationReceivedEvent extends NotificationEvent {
  final RemoteMessage message;
  const NotificationReceivedEvent(this.message);
  @override
  List<Object?> get props => [message];
}

// States
abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationReceived extends NotificationState {
  final RemoteMessage message;
  const NotificationReceived(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(NotificationInitial()) {
    on<InitNotificationsEvent>(_onInit);
    on<NotificationReceivedEvent>(_onReceived);
  }

  Future<void> _onInit(InitNotificationsEvent e, Emitter<NotificationState> emit) async {
    FirebaseMessaging.onMessage.listen((message) {
      add(NotificationReceivedEvent(message));
    });
  }

  Future<void> _onReceived(NotificationReceivedEvent e, Emitter<NotificationState> emit) async {
    emit(NotificationReceived(e.message));
  }
}
