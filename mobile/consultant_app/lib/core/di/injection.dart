import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../network/api_client.dart';

final getIt = GetIt.instance;

Future<void> setupDI() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<StorageService>(StorageService(prefs));

  final dio = Dio(BaseOptions(
    baseUrl: 'https://coaching-backend-ft67.onrender.com/api/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Inject auth token
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = getIt<StorageService>().getToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
  ));

  getIt.registerSingleton<ApiClient>(ApiClient(dio));
}
