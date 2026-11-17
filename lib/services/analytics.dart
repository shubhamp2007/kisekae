import 'package:dio/dio.dart';
import 'package:kisekae/models/dashboard_model.dart';
import 'package:kisekae/models/revenue_analytics.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class Analytics extends BaseRepository {
  final Dio _dio;

  Analytics([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<DashboardMetrics> getStoreDashboardMetrics({
    required int storeId,
    String? fromDate,
    String? toDate,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{
        if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
      };

      final response = await _dio.get(
        '/stores/$storeId/analytics/dashboard/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return DashboardMetrics.fromJson(data);
    });
  }

  Future<RevenueAnalytics> getStoreRevenueAnalytics({
    required int storeId,
    String? period,
    String? fromDate,
    String? toDate,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{
        if (period != null && period.isNotEmpty) 'period': period,
        if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
      };

      final response = await _dio.get(
        '/stores/$storeId/analytics/revenue/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return RevenueAnalytics.fromJson(data);
    });
  }
}
