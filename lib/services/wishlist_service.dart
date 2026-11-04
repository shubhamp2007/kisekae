import 'package:dio/dio.dart';
import 'package:kisekae/models/wishlist.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class WishlistService extends BaseRepository {
  final Dio _dio;

  WishlistService([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Map<String, dynamic>? _dataMap(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return Map<String, dynamic>.from(body);
    }
    return null;
  }

  Map<String, dynamic> _bodyMap(dynamic body) {
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{};
  }

  List<dynamic> _dataList(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is List) return inner;
      return [];
    }
    if (body is List) return body;
    return [];
  }

  Future<List<WishlistItem>> getWishlistItems() async {
    return execute(() async {
      final response = await _dio.get('/profile/wishlist/');

      final list = _dataList(response.data);

      return list
          .map(
            (item) =>
                WishlistItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    });
  }

  Future<WishlistItem> addToWishlist({
    required int productId,
    String note = '',
  }) async {
    return execute(() async {
      final payload = {'product_id': productId, 'note': note};

      final response = await _dio.post('/profile/wishlist/', data: payload);

      return WishlistItem.fromJson(_dataMap(response.data)!);
    });
  }

  Future<String> clearWishlist() async {
    return execute(() async {
      final response = await _dio.delete('/profile/wishlist/');

      if (response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        return body['message']?.toString() ?? 'Wishlist cleared successfully.';
      }
      return 'Wishlist cleared successfully.';
    });
  }

  Future<String> removeWishlistItem(int productId) async {
    return execute(() async {
      final response = await _dio.delete('/profile/wishlist/$productId/');

      if (response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        return body['message']?.toString() ??
            'Item removed from wishlist successfully.';
      }
      return 'Item removed from wishlist successfully.';
    });
  }

  Future<MoveToCartResult> moveToCart(int productId) async {
    return execute(() async {
      final response = await _dio.post(
        '/profile/wishlist/$productId/move-to-cart/',
      );

      return MoveToCartResult.fromJson(_bodyMap(response.data));
    });
  }

  Future<BulkMoveToCartResult> bulkMoveToCart(List<int> productIds) async {
    return execute(() async {
      final payload = {'product_ids': productIds};

      final response = await _dio.post(
        '/profile/wishlist/move-to-cart/',
        data: payload,
      );

      return BulkMoveToCartResult.fromJson(_bodyMap(response.data));
    });
  }
}
