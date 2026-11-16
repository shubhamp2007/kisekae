import 'package:dio/dio.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/product_detail.dart';
import 'package:kisekae/models/recommend_products.dart';

import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class Product extends BaseRepository {
  final Dio _dio;

  Product({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<PaginatedProducts> getProducts({
    String? category,
    String? type,
    String? color,
    String? size,
    bool? inStock,
    String? letter,
    double? minPrice,
    double? maxPrice,
    String? ordering,
    String? search,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (type != null && type.isNotEmpty) 'type': type,
        if (color != null && color.isNotEmpty) 'color': color,
        if (size != null && size.isNotEmpty) 'size': size,
        if (inStock != null) 'in_stock': inStock,
        if (letter != null && letter.isNotEmpty) 'letter': letter,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'page_size': pageSize,
      };

      final response = await _dio.get(
        '/products/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return PaginatedProducts.fromJson(data);
    });
  }

  Future<RecommendedProducts> getRecommendedProducts({
    String? category,
    bool? excludeCart,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final queryParams = <String, dynamic>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (excludeCart != null) 'exclude_cart': excludeCart,
        'page': page,
        'page_size': pageSize,
      };

      final response = await _dio.get(
        '/products/recommended/',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return RecommendedProducts.fromJson(data);
    });
  }

  Future<ProductDetail> getProductDetail(
    int productPk, {
    CancelToken? cancelToken,
  }) async {
    return execute(() async {
      final response = await _dio.get(
        '/products/$productPk/',
        cancelToken: cancelToken,
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = Map<String, dynamic>.from(body['data'] as Map);

      return ProductDetail.fromJson(data);
    });
  }

  Future<PaginatedProducts> searchProducts({
    String? query,
    String? letter,
    String? ordering,
    int? page,
    int? pageSize,
  }) {
    return execute(() async {
      final Map<String, dynamic> queryParams = {};

      if (query != null && query.isNotEmpty) queryParams['q'] = query;
      if (letter != null && letter.isNotEmpty) queryParams['letter'] = letter;
      if (ordering != null && ordering.isNotEmpty) {
        queryParams['ordering'] = ordering;
      }
      if (page != null) queryParams['page'] = page;
      if (pageSize != null) queryParams['page_size'] = pageSize;

      final response = await _dio.get(
        '/products/search/',
        queryParameters: queryParams,
      );

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        return PaginatedProducts.fromJson(responseData);
      }

      throw ApiException(
        statusCode: response.statusCode,
        success: false,
        message: 'Invalid response format received from server',
      );
    });
  }
}
