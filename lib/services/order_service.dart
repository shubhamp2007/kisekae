import 'package:dio/dio.dart';
import 'package:kisekae/models/customer_order.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class OrderService extends BaseRepository {
  final Dio _dio;

  OrderService([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Map<String, dynamic>? _dataMap(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return Map<String, dynamic>.from(body);
    }
    return null;
  }

  List<dynamic> _dataList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final inner = body['data'];
      if (inner is List) return inner;
      if (inner is Map && inner['results'] is List) {
        return inner['results'] as List;
      }
      if (body['results'] is List) return body['results'] as List;
    }
    return [];
  }

  Future<List<CustomerOrderSummary>> getOrders({
    String? status,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final response = await _dio.get(
        '/orders/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final list = _dataList(response.data);

      return list
          .map(
            (item) => CustomerOrderSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    });
  }

  Future<OrderDetail> getOrderDetail(
    int orderId, {
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final response = await _dio.get(
        '/orders/$orderId/',
        cancelToken: cancelToken,
      );

      return OrderDetail.fromJson(_dataMap(response.data)!);
    });
  }

  Future<OrderDetail> cancelOrder(
    int orderId, {
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final response = await _dio.post(
        '/orders/$orderId/cancel/',
        cancelToken: cancelToken,
      );

      return OrderDetail.fromJson(_dataMap(response.data)!);
    });
  }

  Future<OrderDetail> requestRefund(
    int orderId, {
    required String reason,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final response = await _dio.post(
        '/orders/$orderId/request-refund/',
        data: {'reason': reason},
        cancelToken: cancelToken,
      );

      return OrderDetail.fromJson(_dataMap(response.data)!);
    });
  }

  Future<OrderTrackingDetail> trackOrder(
    int orderId, {
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final response = await _dio.get(
        '/orders/$orderId/track/',
        cancelToken: cancelToken,
      );

      return OrderTrackingDetail.fromJson(_dataMap(response.data)!);
    });
  }
}
