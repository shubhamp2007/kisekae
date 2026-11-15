import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/customer_order.dart';
import 'package:kisekae/screens/myorder_detail.dart';
import 'package:kisekae/services/order_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final OrderService _orderService = OrderService();
  CancelToken? _cancelToken;

  bool _isLoading = true;
  List<CustomerOrderSummary> _orders = [];
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'CONFIRMED',
    'PROCESSING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _cancelToken?.cancel("MyOrdersScreen disposed");
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

  Future<void> _fetchOrders() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() => _isLoading = true);

    try {
      final statusParam = _selectedStatus == 'ALL' ? null : _selectedStatus;
      final result = await _orderService.getOrders(
        status: statusParam,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _orders = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && e is! DioException) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: ${e.toString()}')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    final cs = context.cs;
    final c = context.appColors;
    final isDark = cs.brightness == Brightness.dark;

    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return c.success;
      case 'SHIPPED':
      case 'PROCESSING':
        return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case 'CONFIRMED':
      case 'PENDING':
        return c.warning;
      case 'CANCELLED':
        return cs.error;
      default:
        return cs.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;

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
          "My Orders",
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatus == filter;

                return GestureDetector(
                  onTap: () {
                    if (_selectedStatus != filter) {
                      setState(() => _selectedStatus = filter);
                      _fetchOrders();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? cs.primary : c.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Orders List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: c.mutedText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No orders found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.mutedText,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: cs.primary,
                    backgroundColor: c.card,
                    onRefresh: _fetchOrders,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final statusColor = _getStatusColor(order.status);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailsScreen(orderId: order.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.border),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.shadow.withAlpha(31),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Order: ${order.orderNumber}",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withAlpha(31),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _formatStatus(order.status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Item Count & Date
                                Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: c.mutedText,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${order.itemsCount} Item${order.itemsCount > 1 ? 's' : ''}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      order.createdAt.length >= 10
                                          ? order.createdAt.substring(0, 10)
                                          : order.createdAt,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 20, color: c.border),

                                // Total Price & Navigation Arrow
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total: ₹${order.totalAmount}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "View Details",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: c.mutedText,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: c.mutedText,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
