class WishlistStore {
  final int id;
  final String name;
  final String slug;

  WishlistStore({required this.id, required this.name, required this.slug});

  factory WishlistStore.fromJson(Map<String, dynamic> json) {
    return WishlistStore(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

class WishlistProduct {
  final int id;
  final String name;
  final String slug;
  final String price;
  final String? compareAtPrice;
  final String currency;
  final String? imageUrl;
  final String sku;
  final int stock;
  final bool isInStock;
  final String status;
  final WishlistStore? store;

  WishlistProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    this.compareAtPrice,
    required this.currency,
    this.imageUrl,
    required this.sku,
    required this.stock,
    required this.isInStock,
    required this.status,
    this.store,
  });

  factory WishlistProduct.fromJson(Map<String, dynamic> json) {
    return WishlistProduct(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      price: json['price'] as String? ?? '0.00',
      compareAtPrice: json['compare_at_price'] as String?,
      currency: json['currency'] as String? ?? 'INR',
      imageUrl: json['image_url'] as String?,
      sku: json['sku'] as String? ?? '',
      stock: json['stock'] as int? ?? 0,
      isInStock: json['is_in_stock'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      store: json['store'] != null
          ? WishlistStore.fromJson(
              Map<String, dynamic>.from(json['store'] as Map),
            )
          : null,
    );
  }
}

class WishlistItem {
  final int id;
  final String? note;
  final String createdAt;
  final WishlistProduct product;

  WishlistItem({
    required this.id,
    this.note,
    required this.createdAt,
    required this.product,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as int? ?? 0,
      note: json['note'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      product: WishlistProduct.fromJson(
        Map<String, dynamic>.from(json['product'] as Map),
      ),
    );
  }
}

class MoveToCartResult {
  final String message;
  final int productId;
  final int cartItemId;
  final int cartId;

  MoveToCartResult({
    required this.message,
    required this.productId,
    required this.cartItemId,
    required this.cartId,
  });

  factory MoveToCartResult.fromJson(Map<String, dynamic> body) {
    final rawData = body['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return MoveToCartResult(
      message: body['message']?.toString() ?? 'Moved to cart',
      productId: data['product_id'] as int? ?? 0,
      cartItemId: data['cart_item_id'] as int? ?? 0,
      cartId: data['cart_id'] as int? ?? 0,
    );
  }
}

class BulkMoveToCartResult {
  final String message;
  final int movedCount;
  final int skippedCount;
  final List<String> movedItems;
  final List<String> skippedItems;
  final int cartId;
  final int totalCartItems;

  BulkMoveToCartResult({
    required this.message,
    required this.movedCount,
    required this.skippedCount,
    required this.movedItems,
    required this.skippedItems,
    required this.cartId,
    required this.totalCartItems,
  });

  factory BulkMoveToCartResult.fromJson(Map<String, dynamic> body) {
    final rawData = body['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return BulkMoveToCartResult(
      message:
          body['message']?.toString() ?? 'Items moved to cart successfully.',
      movedCount: data['moved_count'] as int? ?? 0,
      skippedCount: data['skipped_count'] as int? ?? 0,
      movedItems:
          (data['moved_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      skippedItems:
          (data['skipped_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cartId: data['cart_id'] as int? ?? 0,
      totalCartItems: data['total_cart_items'] as int? ?? 0,
    );
  }
}
