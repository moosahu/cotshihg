import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/auth_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthEvent extends AuthEvent {}
class SendOTPEvent extends AuthEvent {
  final String phone;
  const SendOTPEvent({required this.phone});
  @override
  List<Object?> get props => [phone];
}
class VerifyOTPEvent extends AuthEvent {
  final String firebaseToken;
  final String phone;
  const VerifyOTPEvent({required this.firebaseToken, required this.phone});
  @override
  List<Object?> get props => [firebaseToken, phone];
}
class RegisterEvent extends AuthEvent {
  final String name;
  final String gender;
  final String role;
  const RegisterEvent({required this.name, required this.gender, required this.role});
  @override
  List<Object?> get props => [name, gender, role];
}
class LogoutEvent extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;
  const AuthAuthenticated({required this.user});
  @override
  List<Object?> get props => [user];
}
class AuthUnauthenticated extends AuthState {}
class OTPSent extends AuthState {}
class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(AuthInitial()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<SendOTPEvent>(_onSendOTP);
    on<VerifyOTPEvent>(_onVerifyOTP);
    on<RegisterEvent>(_onRegister);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuth(CheckAuthEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSendOTP(SendOTPEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repository.sendOTP(event.phone);
      emit(OTPSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOTP(VerifyOTPEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _repository.verifyOTP(event.firebaseToken, event.phone);
      emit(AuthAuthenticated(user: result['user']));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _repository.register(
        name: event.name,
        gender: event.gender,
        role: event.role,
      );
      emit(AuthAuthenticated(user: result));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(AuthUnauthenticated());
  }
}
