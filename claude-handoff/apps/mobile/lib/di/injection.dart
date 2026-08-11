import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt.registerLazySingleton<Dio>(() => Dio(BaseOptions(
    // Points at the API gateway. On the Android emulator `10.0.2.2` resolves
    // to the host loopback. Override at build time with
    // --dart-define=API_BASE_URL=https://gateway.example.com/api/v1
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api/v1',
    ),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  )));

  getIt.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());
  getIt.registerLazySingleton<ApiService>(() => ApiService());
}



