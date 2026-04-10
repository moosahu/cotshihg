import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/therapists/data/repositories/therapist_repository.dart';
import '../../features/therapists/presentation/bloc/therapist_bloc.dart';
import '../../features/booking/data/repositories/booking_repository.dart';
import '../../features/booking/presentation/bloc/booking_bloc.dart';
import '../../features/mood/data/repositories/mood_repository.dart';
import '../../features/mood/presentation/bloc/mood_bloc.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // FlutterSecureStorage — encrypted on both iOS (Keychain) and Android (Keystore)
  const secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Core
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<StorageService>(StorageService(prefs, secure));
  getIt.registerSingleton<Dio>(_createDio());
  getIt.registerSingleton<ApiClient>(ApiClient(getIt<Dio>()));
  getIt.registerSingleton<SocketService>(SocketService(getIt<StorageService>()));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt<ApiClient>(), getIt<StorageService>()));
  getIt.registerLazySingleton<TherapistRepository>(() => TherapistRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<BookingRepository>(() => BookingRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<MoodRepository>(() => MoodRepository(getIt<ApiClient>()));

  // BLoCs
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));
  getIt.registerFactory<TherapistBloc>(() => TherapistBloc(getIt<TherapistRepository>()));
  getIt.registerFactory<BookingBloc>(() => BookingBloc(getIt<BookingRepository>()));
  getIt.registerFactory<MoodBloc>(() => MoodBloc(getIt<MoodRepository>()));
  getIt.registerFactory<NotificationBloc>(() => NotificationBloc());
}

Dio _createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://coaching-backend-ft67.onrender.com/api/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await getIt<StorageService>().getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Token expired — clear storage and redirect to login
        await getIt<StorageService>().clearSession();
        AppRouter.navigatorKey.currentContext?.go('/login');
      }
      handler.next(error);
    },
  ));

  return dio;
}
