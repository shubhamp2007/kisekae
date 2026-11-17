import 'package:kisekae/models/product_detail.dart';

class RecommendedProducts {
  final int count;
  final String? next;
  final String? previous;

  final List<ProductDetail> results;

  final List<ProductDetail> adProducts;

  const RecommendedProducts({
    required this.count,
    this.next,
    this.previous,
    required this.results,
    required this.adProducts,
  });

  bool get hasNext => next != null && next!.isNotEmpty;

  factory RecommendedProducts.fromJson(Map<String, dynamic> json) {
    return RecommendedProducts(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: _parseProducts(json['results']),
      adProducts: _parseProducts(json['ad_products']),
    );
  }

  static List<ProductDetail> _parseProducts(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => ProductDetail.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
