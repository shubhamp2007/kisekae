import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> write(String accessToken) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
    ]);
  }

  Future<void> deleteAll() async {
    await Future.wait([_storage.delete(key: _accessTokenKey)]);
  }
}

class CookieStorage implements Storage {
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    return await _secureStorage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (var key in keys) {
      await _secureStorage.delete(key: key);
    }
  }

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}
}
