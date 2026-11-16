import 'package:kisekae/models/buyer_seasonal_sale.dart';

class SaleProduct {
  final int id;
  final int productId;
  final int saleProductId;
  final String name;
  final String slug;
  final int storeId;
  final String storeName;
  final String storeSlug;
  final String price;
  final String originalPrice;
  final String? compareAtPrice;
  final String discountPercentage;
  final String currency;
  final String thumbnail;
  final String imageUrl;
  final String category;
  final String categoryDisplay;
  final String productType;
  final String productTypeDisplay;
  final String color;
  final int stock;
  final bool isInStock;
  final List<String> availableSizes;
  final double averageRating;
  final int reviewCount;

  SaleProduct({
    required this.id,
    required this.productId,
    required this.saleProductId,
    required this.name,
    required this.slug,
    required this.storeId,
    required this.storeName,
    required this.storeSlug,
    required this.price,
    required this.originalPrice,
    this.compareAtPrice,
    required this.discountPercentage,
    required this.currency,
    required this.thumbnail,
    required this.imageUrl,
    required this.category,
    required this.categoryDisplay,
    required this.productType,
    required this.productTypeDisplay,
    required this.color,
    required this.stock,
    required this.isInStock,
    required this.availableSizes,
    required this.averageRating,
    required this.reviewCount,
  });

  factory SaleProduct.fromJson(Map<String, dynamic> json) {
    return SaleProduct(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      saleProductId: json['sale_product_id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String,
      storeSlug: json['store_slug'] as String,
      price: json['price'] as String,
      originalPrice: json['original_price'] as String,
      compareAtPrice: json['compare_at_price'] as String?,
      discountPercentage: json['discount_percentage'] as String,
      currency: json['currency'] as String,
      thumbnail: json['thumbnail'] as String,
      imageUrl: json['image_url'] as String,
      category: json['category'] as String,
      categoryDisplay: json['category_display'] as String,
      productType: json['product_type'] as String,
      productTypeDisplay: json['product_type_display'] as String,
      color: json['color'] as String,
      stock: json['stock'] as int,
      isInStock: json['is_in_stock'] as bool,
      availableSizes: List<String>.from(json['available_sizes'] ?? []),
      averageRating: (json['average_rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'sale_product_id': saleProductId,
      'name': name,
      'slug': slug,
      'store_id': storeId,
      'store_name': storeName,
      'store_slug': storeSlug,
      'price': price,
      'original_price': originalPrice,
      'compare_at_price': compareAtPrice,
      'discount_percentage': discountPercentage,
      'currency': currency,
      'thumbnail': thumbnail,
      'image_url': imageUrl,
      'category': category,
      'category_display': categoryDisplay,
      'product_type': productType,
      'product_type_display': productTypeDisplay,
      'color': color,
      'stock': stock,
      'is_in_stock': isInStock,
      'available_sizes': availableSizes,
      'average_rating': averageRating,
      'review_count': reviewCount,
    };
  }
}

class SaleProductsResponse {
  final SeasonalSale sale;
  final int count;
  final String? next;
  final String? previous;
  final List<SaleProduct> results;

  SaleProductsResponse({
    required this.sale,
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory SaleProductsResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = Map<String, dynamic>.from(json['data'] as Map);
    final resultsList = dataMap['results'] as List<dynamic>? ?? [];

    return SaleProductsResponse(
      sale: SeasonalSale.fromJson(
        Map<String, dynamic>.from(dataMap['sale'] as Map),
      ),
      count: dataMap['count'] as int,
      next: dataMap['next'] as String?,
      previous: dataMap['previous'] as String?,
      results: resultsList
          .map(
            (item) =>
                SaleProduct.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
