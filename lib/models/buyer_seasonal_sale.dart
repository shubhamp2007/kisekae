class SeasonalSale {
  final int id;
  final String title;
  final String slug;
  final String description;
  final String bannerImage;
  final String discountPercentage;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLive;
  final int timeRemainingSeconds;
  final int participatingProductsCount;
  final DateTime createdAt;
  final int? participatingStoresCount;

  SeasonalSale({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.bannerImage,
    required this.discountPercentage,
    required this.startTime,
    required this.endTime,
    required this.isLive,
    required this.timeRemainingSeconds,
    required this.participatingProductsCount,
    required this.createdAt,
    this.participatingStoresCount,
  });

  factory SeasonalSale.fromJson(Map<String, dynamic> json) {
    return SeasonalSale(
      id: json['id'] as int,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String,
      bannerImage: json['banner_image'] as String,
      discountPercentage: json['discount_percentage'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      isLive: json['is_live'] as bool,
      timeRemainingSeconds: json['time_remaining_seconds'] as int,
      participatingProductsCount: json['participating_products_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      participatingStoresCount: json['participating_stores_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'description': description,
      'banner_image': bannerImage,
      'discount_percentage': discountPercentage,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_live': isLive,
      'time_remaining_seconds': timeRemainingSeconds,
      'participating_products_count': participatingProductsCount,
      'created_at': createdAt.toIso8601String(),
      if (participatingStoresCount != null)
        'participating_stores_count': participatingStoresCount,
    };
  }
}
