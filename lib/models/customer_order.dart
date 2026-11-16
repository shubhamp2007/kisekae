class CustomerOrderSummary {
  final int id;
  final int userId;
  final String orderNumber;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String status;
  final String totalAmount;
  final String currency;
  final int itemsCount;
  final String? deliveredAt;
  final String createdAt;
  final String updatedAt;

  CustomerOrderSummary({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.itemsCount,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerOrderSummary.fromJson(Map<String, dynamic> json) {
    return CustomerOrderSummary(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      totalAmount: json['total_amount']?.toString() ?? '0',
      currency: json['currency'] as String? ?? 'INR',
      itemsCount: json['items_count'] as int? ?? 0,
      deliveredAt: json['delivered_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class OrderItem {
  final int id;
  final int product;
  final String productName;
  final String productSku;
  final String size;
  final String unitPrice;
  final int quantity;
  final String totalPrice;

  OrderItem({
    required this.id,
    required this.product,
    required this.productName,
    required this.productSku,
    required this.size,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int? ?? 0,
      product: json['product'] as int? ?? 0,
      productName: json['product_name'] as String? ?? '',
      productSku: json['product_sku'] as String? ?? '',
      size: json['size'] as String? ?? '',
      unitPrice: json['unit_price']?.toString() ?? '0',
      quantity: json['quantity'] as int? ?? 1,
      totalPrice: json['total_price']?.toString() ?? '0',
    );
  }

  double get parsedUnitPrice => double.tryParse(unitPrice) ?? 0.0;
  double get parsedTotalPrice => double.tryParse(totalPrice) ?? 0.0;
}

class OrderStatusHistory {
  final int id;
  final String? fromStatus;
  final String toStatus;
  final String? notes;
  final int? changedBy;
  final String? changedByName;
  final String createdAt;

  OrderStatusHistory({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.notes,
    this.changedBy,
    this.changedByName,
    required this.createdAt,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      id: json['id'] as int? ?? 0,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String? ?? '',
      notes: json['notes'] as String?,
      changedBy: json['changed_by'] as int?,
      changedByName: json['changed_by_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  factory OrderStatusHistory.fromEvent(Map<String, dynamic> json, int index) {
    return OrderStatusHistory(
      id: index,
      toStatus: json['event'] as String? ?? json['status'] as String? ?? '',
      createdAt: json['timestamp'] as String? ?? '',
    );
  }
}

class OrderDetail {
  final int id;
  final int userId;
  final String orderNumber;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String shippingAddress;
  final String status;
  final String totalAmount;
  final String currency;
  final String? trackingNumber;
  final String? trackingUrl;
  final String? notes;
  final String? deliveredAt;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;
  final String createdAt;
  final String updatedAt;

  OrderDetail({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.shippingAddress,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.trackingNumber,
    this.trackingUrl,
    this.notes,
    this.deliveredAt,
    required this.items,
    required this.statusHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawHistory = json['status_history'] as List<dynamic>? ?? [];

    return OrderDetail(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      shippingAddress: json['shipping_address'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      totalAmount: json['total_amount']?.toString() ?? '0',
      currency: json['currency'] as String? ?? 'INR',
      trackingNumber: json['tracking_number'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      notes: json['notes'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      items: rawItems
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      statusHistory: rawHistory
          .map(
            (e) => OrderStatusHistory.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  double get parsedTotalAmount => double.tryParse(totalAmount) ?? 0.0;

  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  String get formattedTotal =>
      '$currencySymbol${parsedTotalAmount.toStringAsFixed(0)}';

  String get formattedCreatedDate {
    if (createdAt.length >= 10) return createdAt.substring(0, 10);
    return createdAt;
  }

  String get formattedDeliveredDate {
    if (deliveredAt != null && deliveredAt!.length >= 10) {
      return deliveredAt!.substring(0, 10);
    }
    return '';
  }
}

class OrderTrackingDetail {
  final int id;
  final String orderNumber;
  final String storeName;
  final String status;
  final String totalAmount;
  final String currency;
  final String? trackingNumber;
  final String? trackingUrl;
  final String? deliveredAt;
  final String createdAt;
  final String updatedAt;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;

  OrderTrackingDetail({
    required this.id,
    required this.orderNumber,
    required this.storeName,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.trackingNumber,
    this.trackingUrl,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.statusHistory,
  });

  factory OrderTrackingDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawEvents = json['events'] as List<dynamic>? ?? [];
    final rawHistory = json['status_history'] as List<dynamic>? ?? [];

    final history = rawEvents.isNotEmpty
        ? [
            for (var i = 0; i < rawEvents.length; i++)
              OrderStatusHistory.fromEvent(
                Map<String, dynamic>.from(rawEvents[i] as Map),
                i,
              ),
          ]
        : rawHistory
              .map(
                (e) => OrderStatusHistory.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();

    return OrderTrackingDetail(
      id: json['id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      totalAmount: json['total_amount']?.toString() ?? '0',
      currency: json['currency'] as String? ?? 'INR',
      trackingNumber: json['tracking_number'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      items: rawItems
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      statusHistory: history,
    );
  }

  double get parsedTotalAmount => double.tryParse(totalAmount) ?? 0.0;

  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  String get formattedTotal =>
      '$currencySymbol${parsedTotalAmount.toStringAsFixed(0)}';
}
