import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:dio/dio.dart';
import 'package:kisekae/models/fcm_device.dart';
import 'package:kisekae/models/userprofile.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

import 'package:flutter/foundation.dart';
import 'package:kisekae/services/storage.dart';

class ProfileDetails extends BaseRepository {
  final Dio _dio;

  ProfileDetails([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<UserProfile> getProfile() async {
    return execute(() async {
      final response = await _dio.get('/profile/me/');

      final body = Map<String, dynamic>.from(response.data as Map);
      final profileData = Map<String, dynamic>.from(body['data'] as Map);

      return UserProfile.fromJson(profileData);
    });
  }

  Future<UserProfile> updateProfileName(String name) async {
    return execute(() async {
      final response = await _dio.put('/profile/me/', data: {'name': name});

      final body = Map<String, dynamic>.from(response.data as Map);
      final profileData = Map<String, dynamic>.from(body['data'] as Map);

      return UserProfile.fromJson(profileData);
    });
  }

  Future<String> deleteAccount() async {
    return execute(() async {
      final response = await _dio.delete('/profile/me/');

      final body = Map<String, dynamic>.from(response.data as Map);
      final message =
          body['message']?.toString() ?? 'Account deactivated successfully.';

      await DioClient.clearSession();

      return message;
    });
  }

  Future<List<FcmDevice>> getDevices() async {
    return execute(() async {
      final response = await _dio.get('/profile/devices/');

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = List<Map<String, dynamic>>.from(
        (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      return data.map(FcmDevice.fromJson).toList();
    });
  }

  Future<FcmDevice> registerDevice({
    required String registrationToken,
    required String deviceType,
    String deviceName = '',
  }) async {
    return execute(() async {
      final response = await _dio.post(
        '/profile/devices/',
        data: {
          'registration_token': registrationToken,
          'device_type': deviceType,
          'device_name': deviceName,
        },
      );
      print(response);

      final body = Map<String, dynamic>.from(response.data as Map);
      final deviceData = Map<String, dynamic>.from(body['data'] as Map);

      return FcmDevice.fromJson(deviceData);
    });
  }

  Future<String> unregisterDevice() async {
    return execute(() async {
      final response = await _dio.delete('/profile/devices/');
      final body = Map<String, dynamic>.from(response.data as Map);

      return body['message']?.toString() ?? 'Device unregistered successfully.';
    });
  }

  Future<void> updateFCMToken(String newToken) async {
    try {
      final accessToken = await TokenStorage().readAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;

      await registerDevice(
        registrationToken: newToken,
        deviceType: Platform.isIOS ? 'IOS' : 'ANDROID',
      );
    } catch (e) {
      debugPrint('Failed to sync refreshed FCM token: $e');
    }
  }

  Future<void> registerCurrentFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await updateFCMToken(token);
    } catch (e) {
      debugPrint('Failed to register FCM token on login: $e');
    }
  }
}
