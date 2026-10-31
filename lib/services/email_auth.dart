import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kisekae/models/auth_response.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/storage.dart';

class EmailAuth {
  final Dio dio = DioClient.dio;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await dio.post(
        '/accounts/login/password/',
        data: {"email": email, "password": password},
      );
      if (!await _saveToken(response.data)) {
        return AuthResponse(false, "Token missing from body.");
      } else {
        return AuthResponse(
          true,
          response.data["message"]?.toString() ?? "",
          Map<String, dynamic>.from(response.data["data"] ?? {}),
        );
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      return AuthResponse(
        false,
        body is Map
            ? body["message"].toString()
            : (e.message ?? "Network error"),
      );
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<AuthResponse> signUp(
    String name,
    String email,
    String password, {
    bool isSeller = false,
  }) async {
    try {
      final response = await dio.post(
        '/accounts/register/',
        data: {
          "name": name,
          "email": email,
          "password": password,
          "is_seller": isSeller,
        },
      );
      return AuthResponse(
        true,
        response.data["message"]?.toString() ?? "",
        Map<String, dynamic>.from(response.data["data"] ?? {}),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        final error = body["error"];
        final code = error is Map ? error["code"]?.toString() : null;
        final details = error is Map && error["details"] is Map
            ? Map<String, dynamic>.from(error["details"] as Map)
            : null;
        return AuthResponse(
          false,
          body["message"]?.toString() ?? e.message ?? "Network error",
          null,
          code,
          details,
        );
      }
      return AuthResponse(false, e.message ?? "Network error");
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<AuthResponse> sendOtp(String email, {String purpose = "login"}) async {
    try {
      final response = await dio.post(
        '/accounts/otp/request/',
        data: {"email": email, "purpose": purpose},
      );
      return AuthResponse(true, response.data["message"]?.toString() ?? "");
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        final error = body["error"];
        final code = error is Map ? error["code"]?.toString() : null;
        final details = error is Map && error["details"] is Map
            ? Map<String, dynamic>.from(error["details"] as Map)
            : null;
        return AuthResponse(
          false,
          body["message"]?.toString() ?? e.message ?? "Network error",
          null,
          code,
          details,
        );
      }
      return AuthResponse(false, e.message ?? "Network error");
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<AuthResponse> verifyOtp(
    String email,
    String code, {
    required String purpose,
  }) async {
    try {
      final response = await dio.post(
        '/accounts/otp/verify/',
        data: {"email": email, "code": code, "purpose": purpose},
      );

      final access = response.data?["data"]?["access"];
      if (access is String && access.isNotEmpty) {
        await _tokenStorage.write(access);
      } else if (purpose == "login") {
        return AuthResponse(false, "Token missing from body.");
      }

      return AuthResponse(
        true,
        response.data["message"]?.toString() ?? "",
        Map<String, dynamic>.from(response.data["data"] ?? {}),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      return AuthResponse(
        false,
        body is Map
            ? body["message"].toString()
            : (e.message ?? "Network error"),
      );
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<AuthResponse> resetPassword(String token, String newPassword) async {
    try {
      final response = await dio.post(
        '/accounts/password/reset/',
        data: {"token": token, "new_password": newPassword},
      );
      return AuthResponse(true, response.data["message"]?.toString() ?? "");
    } on DioException catch (e) {
      final body = e.response?.data;
      return AuthResponse(
        false,
        body is Map
            ? body["message"].toString()
            : (e.message ?? "Network error"),
      );
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<AuthResponse> logout() async {
    var message = '';
    try {
      final response = await dio.post('/accounts/logout/');
      message = response.data?["message"]?.toString() ?? "";
    } catch (_) {
    } finally {
      try {
        await DioClient.clearSession();
      } catch (_) {}
      await _tokenStorage.deleteAll();

      try {
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {}
    }
    return AuthResponse(true, message);
  }

  Future<bool> _saveToken(Map<String, dynamic> body) async {
    final data = body['data'];
    if (data is! Map) return false;

    final access = data['access'];
    if (access is! String || access.isEmpty) return false;

    await _tokenStorage.write(access);

    final user = data['user'];
    final isSeller = user is Map ? user['is_seller'] : data['is_seller'];
    if (isSeller is bool) {
      await _tokenStorage.saveIsSeller(isSeller);
    }

    return true;
  }
}
