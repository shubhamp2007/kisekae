import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/models/store_member.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

import '../models/store_create.dart';

enum ReportType {
  sales('sales'),
  inventory('inventory'),
  orders('orders');

  final String value;
  const ReportType(this.value);
}

enum RevenuePeriod {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  final String value;
  const RevenuePeriod(this.value);
}

class StoreOperations extends BaseRepository {
  final Dio _dio;

  StoreOperations([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<PaginatedStoreResponse> getStores({
    bool? includeArchived,
    int? page,
    int? pageSize,
    String? role,
    String? status,
  }) async {
    return execute(() async {
      final Map<String, dynamic> queryParams = {};

      if (includeArchived != null) {
        queryParams['include_archived'] = includeArchived;
      }
      if (page != null) queryParams['page'] = page;
      if (pageSize != null) queryParams['page_size'] = pageSize;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _dio.get('/stores/', queryParameters: queryParams);

      final body = response.data;
      Map<String, dynamic> payload;
      if (body is Map<String, dynamic>) {
        final inner = body['data'];
        if (inner is Map<String, dynamic>) {
          payload = inner;
        } else if (inner is List) {
          payload = {'count': inner.length, 'results': inner};
        } else {
          payload = body;
        }
      } else {
        payload = {'count': 0, 'results': <dynamic>[]};
      }
      return PaginatedStoreResponse.fromJson(payload);
    });
  }

  Future<Store> createStore({
    required String name,
    required String description,
    required File logo,
    required File banner,
    String? websiteLink,
    String? instagramLink,
    String? contactEmail,
    String? contactPhone,
  }) async {
    return execute(() async {
      final formData = FormData.fromMap({
        'name': name,
        'description': description,
        'logo': await _imagePart(logo),
        'banner': await _imagePart(banner),
        if (websiteLink != null) 'website_link': websiteLink,
        if (instagramLink != null) 'instagram_link': instagramLink,
        if (contactEmail != null) 'contact_email': contactEmail,
        if (contactPhone != null) 'contact_phone': contactPhone,
      });

      final response = await _dio.post('/stores/', data: formData);
      final body = response.data as Map<String, dynamic>;
      return Store.fromJson((body['data'] ?? body) as Map<String, dynamic>);
    });
  }

  Future<Store> getStoreById(int storeId) async {
    return execute(() async {
      final response = await _dio.get('/stores/$storeId');
      return Store.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<Store> getStore(int storeId) async {
    return execute(() async {
      final response = await _dio.get('/stores/$storeId/');
      final body = Map<String, dynamic>.from(response.data as Map);
      return Store.fromJson(
        Map<String, dynamic>.from((body['data'] ?? body) as Map),
      );
    });
  }

  Future<Store> updateStore(
    int storeId, {
    String? name,
    String? description,
    File? logo,
    File? banner,
    String? websiteLink,
    String? instagramLink,
    String? contactEmail,
    String? contactPhone,
    String? status,
  }) async {
    return execute(() async {
      final formData = FormData.fromMap({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (logo != null) 'logo': await _imagePart(logo),
        if (banner != null) 'banner': await _imagePart(banner),
        if (websiteLink != null) 'website_link': websiteLink,
        if (instagramLink != null) 'instagram_link': instagramLink,
        if (contactEmail != null) 'contact_email': contactEmail,
        if (contactPhone != null) 'contact_phone': contactPhone,
        if (status != null) 'status': status,
      });

      final response = await _dio.put('/stores/$storeId/', data: formData);
      final body = Map<String, dynamic>.from(response.data as Map);
      return Store.fromJson(
        Map<String, dynamic>.from((body['data'] ?? body) as Map),
      );
    });
  }

  Future<void> archiveStore(int storeId) async {
    return execute(() async {
      await _dio.delete('/stores/$storeId/');
    });
  }

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  Future<dynamic> getRevenueAnalytics({
    required int storeId,
    DateTime? fromDate,
    DateTime? toDate,
    RevenuePeriod? period,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{};

      if (fromDate != null) {
        queryParams['from_date'] = _formatDate(fromDate);
      }
      if (toDate != null) {
        queryParams['to_date'] = _formatDate(toDate);
      }
      if (period != null) {
        queryParams['period'] = period.value;
      }

      final response = await _dio.get(
        '/stores/$storeId/analytics/revenue/',
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      return body['data'];
    });
  }

  Future<MultipartFile> _imagePart(File file) {
    final name = file.path.split('/').last;
    final ext = name.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return MultipartFile.fromFile(
      file.path,
      filename: name,
      contentType: DioMediaType.parse(mime),
    );
  }
}
