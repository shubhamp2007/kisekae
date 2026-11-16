import 'package:dio/dio.dart';
import 'package:kisekae/models/buyer_seasonal_sale.dart';
import 'package:kisekae/models/sale_product.dart';

import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/helper.dart';

class SeasonalSales extends BaseRepository {
  final Dio _dio;

  SeasonalSales([Dio? dio]) : _dio = dio ?? DioClient.dio;

  Future<List<SeasonalSale>> getSales() async {
    return execute(() async {
      final response = await _dio.get('/products/sales/');

      final body = Map<String, dynamic>.from(response.data as Map);
      final data = body['data'] as List<dynamic>? ?? [];

      return data
          .map(
            (item) =>
                SeasonalSale.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    });
  }

  Future<SeasonalSale> getSaleDetails(int salePk) async {
    return execute(() async {
      final response = await _dio.get('/products/sales/$salePk/');

      final body = Map<String, dynamic>.from(response.data as Map);
      final item = Map<String, dynamic>.from(body['data'] as Map);

      return SeasonalSale.fromJson(item);
    });
  }

  Future<SaleProductsResponse> getSaleProducts(
    int salePk, {
    String? category,
    String? color,
    bool? inStock,
    double? maxPrice,
    double? minPrice,
    String? ordering,
    int? page,
    int? pageSize,
    String? q,
    String? size,
  }) async {
    return execute(() async {
      final queryParameters = <String, dynamic>{
        if (category != null) 'category': category,
        if (color != null) 'color': color,
        if (inStock != null) 'in_stock': inStock,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minPrice != null) 'min_price': minPrice,
        if (ordering != null) 'ordering': ordering,
        if (page != null) 'page': page,
        if (pageSize != null) 'page_size': pageSize,
        if (q != null) 'q': q,
        if (size != null) 'size': size,
      };

      final response = await _dio.get(
        '/products/sales/$salePk/products/',
        queryParameters: queryParameters,
      );

      return SaleProductsResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    });
  }
}
