import 'package:dio/dio.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/storage.dart';

class AuthResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AuthResponse(this.success, this.message, [this.data]);
}

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
    String password,
  ) async {
    try {
      final response = await dio.post(
        '/accounts/register/',
        data: {"name": name, "email": email, "password": password},
      );
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

  Future<AuthResponse> sendOtp(String email, {String purpose = "login"}) async {
    try {
      final response = await dio.post(
        '/accounts/otp/request/',
        data: {"email": email, "purpose": purpose},
      );
      print(response);
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

  Future<AuthResponse> verifyOtp(
    String email,
    int code, {
    required String purpose,
  }) async {
    try {
      final response = await dio.post(
        '/accounts/otp/verify/',
        data: {"email": email, "code": code, "purpose": purpose},
      );
      if (purpose == "login") {
        if (!await _saveToken(response.data)) {
          return AuthResponse(false, "Token missing from body.");
        }
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
    try {
      final accessToken = await _tokenStorage.readAccessToken();

      final response = await dio.post(
        '/accounts/logout/',
        options: Options(headers: {"Authorization": "Bearer $accessToken"}),
      );
      await _tokenStorage.deleteAll();
      return AuthResponse(true, response.data["message"]?.toString() ?? "");
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await DioClient.clearSession();
        return AuthResponse(true, "Session already expired.");
      }
      final body = e.response?.data;
      return AuthResponse(
        false,
        body is Map
            ? body["message"].toString()
            : (e.message ?? "Logout failed"),
      );
    } catch (e) {
      return AuthResponse(false, "Unexpected error: $e");
    }
  }

  Future<bool> _saveToken(Map<String, dynamic> body) async {
    final String accessToken = body['data']['access'];
    if (accessToken.isEmpty) {
      return false;
    }

    await _tokenStorage.write(accessToken);

    return true;
  }
}
