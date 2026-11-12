import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/customer_order.dart';
import 'package:kisekae/screens/trackorderscreen.dart';
import 'package:kisekae/services/order_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderService _orderService = OrderService();
  CancelToken? _cancelToken;

  OrderDetail? _orderDetail;
  bool _isLoading = true;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  @override
  void dispose() {
    _cancelToken?.cancel("OrderDetailsScreen disposed");
    super.dispose();
  }

  String _formatStatus(String status) {
    final words = status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((word) => word.isNotEmpty);
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<void> _fetchOrderDetail() async {
    _cancelToken = CancelToken();
    setState(() => _isLoading = true);

    try {
      final detail = await _orderService.getOrderDetail(
        widget.orderId,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _orderDetail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && e is! DioException) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleCancelOrder() async {
    if (_orderDetail == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cancel Order?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ctx.cs.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to cancel Order #${_orderDetail!.orderNumber}?",
          style: TextStyle(color: ctx.cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("NO", style: TextStyle(color: ctx.appColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "YES, CANCEL",
              style: TextStyle(
                color: ctx.cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      final updatedOrder = await _orderService.cancelOrder(
        _orderDetail!.id,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _orderDetail = updatedOrder;
          _isCancelling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order has been cancelled successfully."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to cancel order: ${e.toString()}',
              style: TextStyle(color: context.cs.onError),
            ),
            backgroundColor: context.cs.error,
          ),
        );
      }
    }
  }

  bool _canCancel(String status) {
    final s = status.toUpperCase();
    return s == 'PENDING' || s == 'CONFIRMED';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (_orderDetail == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: cs.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Order details not found",
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: _fetchOrderDetail,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final order = _orderDetail!;
    final canCancelOrder = _canCancel(order.status);
    final isCancelled = order.status.toUpperCase() == 'CANCELLED';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: cs.onSurface,
            ),
          ),
        ),
        title: Text(
          "Order Details",
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ordered Products Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 20, color: c.border),
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Size: ${item.size.isNotEmpty ? item.size : 'N/A'}  |  Qty: ${item.quantity}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.mutedText,
                                ),
                              ),
                              Text(
                                "${order.currencySymbol}${item.parsedTotalPrice.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  Divider(height: 24, color: c.border),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order Number : ${order.orderNumber}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          order.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCancelled ? cs.error : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isCancelled
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TrackOrderScreen(orderId: order.id),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      "Track order",
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (canCancelOrder && !_isCancelling)
                        ? _handleCancelOrder
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: canCancelOrder ? cs.primary : cs.outline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : Text(
                            isCancelled ? "Cancelled" : "Cancel order",
                            style: TextStyle(
                              color: canCancelOrder ? cs.primary : c.mutedText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Delivery Details Section
            Text(
              "Delivery Details",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _detailRow(
                    "Address",
                    order.shippingAddress.isNotEmpty
                        ? order.shippingAddress
                        : "N/A",
                  ),
                  const SizedBox(height: 6),
                  _detailRow(
                    "Date",
                    order.deliveredAt != null && order.deliveredAt!.isNotEmpty
                        ? "Delivered on ${order.formattedDeliveredDate}"
                        : "Ordered on ${order.formattedCreatedDate}",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pricing Details Section
            Text(
              "Pricing Details",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _pricingRow(
                    "Total amount",
                    order.formattedTotal,
                    isBold: true,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        // Download invoice file action
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "DOWNLOAD INVOICE",
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    final onSurface = context.cs.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: onSurface,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, height: 1.3, color: onSurface),
          ),
        ),
      ],
    );
  }

  Widget _pricingRow(String label, String value, {bool isBold = false}) {
    final onSurface = context.cs.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: onSurface,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}
