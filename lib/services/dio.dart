import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kisekae/services/storage.dart';

class DioClient {
  DioClient._();

  static late final Dio dio;
  static late final PersistCookieJar cookieJar;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    cookieJar = PersistCookieJar(storage: CookieStorage());
    dio = Dio(BaseOptions(baseUrl: dotenv.get('BASE_URL')));

    dio.interceptors.addAll([
      CookieManager(cookieJar),
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final hadAuthHeader = error.requestOptions.headers.containsKey(
            'Authorization',
          );

          if (error.response?.statusCode == 401 && hadAuthHeader) {
            print("Session Expired. Logging Out...");
            await clearSession();
            return handler.next(error);
          }
          if (error.response?.statusCode == 500) {
            print("Server Error");
          }
          return handler.next(error);
        },
      ),
    ]);

    _initialized = true;
  }

  static Future<void> clearSession() async {
    await TokenStorage().deleteAll();
    await cookieJar.deleteAll();
  }
}
