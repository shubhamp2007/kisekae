import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/services/order_seller.dart';

import '../models/order_details.dart';

class OrderDetailScreen extends StatefulWidget {
  final int storeId;
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.storeId,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final StoreOrderRepository _orderService = StoreOrderRepository();

  OrderDetail? _order;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    setState(() => _isLoading = true);

    try {
      final order = await _orderService.getOrderDetails(
        storeId: widget.storeId,
        orderId: widget.orderId,
      );

      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && e is! DioException) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load order details: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleUpdateStatus({
    required String newStatus,
    String? notes,
    String? trackingNumber,
    String? trackingUrl,
  }) async {
    if (_order == null) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final updatedOrder = await _orderService.updateOrderStatus(
        storeId: widget.storeId,
        orderId: widget.orderId,
        status: newStatus,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        trackingNumber: trackingNumber?.trim().isNotEmpty == true
            ? trackingNumber!.trim()
            : null,
        trackingUrl: trackingUrl?.trim().isNotEmpty == true
            ? trackingUrl!.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _order = updatedOrder;
          _isUpdatingStatus = false;
        });

        final isDark =
            Theme.of(context).colorScheme.brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Order status updated to $newStatus successfully!",
              style: TextStyle(color: isDark ? Colors.black : Colors.white),
            ),
            backgroundColor: context.appColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: ${e.toString()}',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  String _formatCurrency(String amount, String currency) {
    final parsed = double.tryParse(amount) ?? 0.0;
    final symbol = currency.toUpperCase() == 'INR'
        ? '₹'
        : currency.toUpperCase() == 'USD'
        ? '\$'
        : currency;
    return '$symbol${parsed.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _getStatusStyle(String status) {
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    final isDark = cs.brightness == Brightness.dark;

    late final Color color;
    late final String label;
    late final IconData icon;

    switch (status.toUpperCase()) {
      case 'DELIVERED':
        color = app.success;
        label = 'DELIVERED';
        icon = Icons.check_circle_outline;
        break;
      case 'SHIPPED':
        color = isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0288D1);
        label = 'SHIPPED';
        icon = Icons.local_shipping_outlined;
        break;
      case 'OUT_FOR_DELIVERY':
        color = isDark ? const Color(0xFFFF8A65) : const Color(0xFFE65100);
        label = 'OUT FOR DELIVERY';
        icon = Icons.delivery_dining_outlined;
        break;
      case 'CANCELLED':
        color = cs.error;
        label = 'CANCELLED';
        icon = Icons.cancel_outlined;
        break;
      case 'PENDING':
      default:
        color = app.warning;
        label = 'PENDING';
        icon = Icons.schedule_outlined;
    }

    return {
      'label': label,
      'color': color,
      'bgColor': color.withValues(alpha: 0.15),
      'icon': icon,
    };
  }

  void _showUpdateStatusSheet(BuildContext context) {
    const validStatuses = [
      'SHIPPED',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
      'CANCELLED',
    ];
    String currentStatus = _order?.status.toUpperCase() ?? '';
    String selectedStatus = validStatuses.contains(currentStatus)
        ? currentStatus
        : 'SHIPPED';

    final notesController = TextEditingController(text: _order?.notes ?? '');
    final trackingNumberController = TextEditingController(
      text: _order?.trackingNumber ?? '',
    );
    final trackingUrlController = TextEditingController(
      text: _order?.trackingUrl ?? '',
    );

    final colors = Theme.of(context).colorScheme;
    final primaryColor = colors.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Update Order Status",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip(
                          label: "OUT FOR DELIVERY",
                          color:
                              _getStatusStyle('OUT_FOR_DELIVERY')['color']
                                  as Color,
                          isSelected: selectedStatus == "OUT_FOR_DELIVERY",
                          onTap: () => setSheetState(
                            () => selectedStatus = "OUT_FOR_DELIVERY",
                          ),
                        ),
                        _statusChip(
                          label: "SHIPPED",
                          color: _getStatusStyle('SHIPPED')['color'] as Color,
                          isSelected: selectedStatus == "SHIPPED",
                          onTap: () =>
                              setSheetState(() => selectedStatus = "SHIPPED"),
                        ),
                        _statusChip(
                          label: "DELIVERED",
                          color: _getStatusStyle('DELIVERED')['color'] as Color,
                          isSelected: selectedStatus == "DELIVERED",
                          onTap: () =>
                              setSheetState(() => selectedStatus = "DELIVERED"),
                        ),
                        _statusChip(
                          label: "CANCELLED",
                          color: _getStatusStyle('CANCELLED')['color'] as Color,
                          isSelected: selectedStatus == "CANCELLED",
                          onTap: () =>
                              setSheetState(() => selectedStatus = "CANCELLED"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (selectedStatus == "SHIPPED" ||
                        selectedStatus == "OUT_FOR_DELIVERY" ||
                        selectedStatus == "DELIVERED") ...[
                      TextFormField(
                        controller: trackingNumberController,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(
                          "Tracking Number (Optional)",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: trackingUrlController,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration("Tracking URL (Optional)"),
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration(
                        "Status Notes / Comments (Optional)",
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleUpdateStatus(
                            newStatus: selectedStatus,
                            notes: notesController.text,
                            trackingNumber: trackingNumberController.text,
                            trackingUrl: trackingUrlController.text,
                          );
                        },
                        child: Text(
                          "Update Status to ${selectedStatus.replaceAll('_', ' ')}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final onColor = isDark ? Colors.black : Colors.white;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? onColor : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? color : Colors.transparent),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: context.appColors.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = colors.surface;
    final primaryColor = colors.primary;
    final cardBackgroundColor = context.appColors.card;
    final borderColor = colors.outlineVariant;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: colors.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Order details not available"),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: colors.onPrimary,
                ),
                onPressed: _fetchOrderDetails,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final statusStyle = _getStatusStyle(order.status);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: colors.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: colors.onSurface,
            ),
          ),
        ),
        title: Text(
          "Order Details",
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _fetchOrderDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order #${order.orderNumber}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Placed on ${_formatDate(order.createdAt)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusStyle['bgColor'] as Color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusStyle['icon'] as IconData,
                                size: 14,
                                color: statusStyle['color'] as Color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusStyle['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusStyle['color'] as Color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: borderColor),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _showUpdateStatusSheet(context),
                        icon: _isUpdatingStatus
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : Icon(
                                Icons.edit_road_outlined,
                                color: primaryColor,
                                size: 18,
                              ),
                        label: Text(
                          _isUpdatingStatus
                              ? "Updating Status..."
                              : "Update Order Status",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Customer & Delivery Info",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    Divider(height: 20, color: borderColor),
                    _infoRow(
                      Icons.person_outline,
                      "Customer",
                      order.customerName,
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.phone_outlined,
                      "Phone",
                      order.customerPhone,
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.email_outlined,
                      "Email",
                      order.customerEmail,
                    ),
                    if (order.shippingAddress != null &&
                        order.shippingAddress!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.location_on_outlined,
                        "Shipping Address",
                        order.shippingAddress!,
                      ),
                    ],
                    if (order.trackingNumber != null &&
                        order.trackingNumber!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(
                        Icons.local_shipping_outlined,
                        "Tracking #",
                        order.trackingNumber!,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Order Items",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          "${order.items.length} item(s)",
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 20, color: borderColor),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 20, color: borderColor),
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.outlineVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.checkroom,
                                color: colors.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (item.size != null &&
                                          item.size!.isNotEmpty) ...[
                                        Text(
                                          "Size: ${item.size}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Text(
                                        "Qty: ${item.quantity}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(item.totalPrice, order.currency),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Order Amount",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      _formatCurrency(order.totalAmount, order.currency),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
