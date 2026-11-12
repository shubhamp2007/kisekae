import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/models/customer_order.dart';

import 'package:kisekae/services/order_service.dart';

class TrackOrderScreen extends StatefulWidget {
  final int orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final OrderService _orderService = OrderService();
  CancelToken? _cancelToken;

  OrderTrackingDetail? _trackingDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrackingData();
  }

  @override
  void dispose() {
    _cancelToken?.cancel("TrackOrderScreen disposed");
    super.dispose();
  }

  Future<void> _fetchTrackingData() async {
    _cancelToken = CancelToken();
    setState(() => _isLoading = true);

    try {
      final detail = await _orderService.trackOrder(
        widget.orderId,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _trackingDetail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && e is! DioException) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tracking data: ${e.toString()}'),
          ),
        );
      }
    }
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    final year = parsed.year;
    final month = _getMonthName(parsed.month);
    final day = parsed.day;
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year - $hour:$minute $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = colors.surface;
    final primaryColor = colors.primary;
    final cardBackgroundColor = colors.surfaceContainerLow;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_trackingDetail == null) {
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
              const Text("Tracking information unavailable"),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: colors.onPrimary,
                ),
                onPressed: _fetchTrackingData,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _trackingDetail!;
    final history = detail.statusHistory;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colors.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Track Order",
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((detail.trackingNumber != null &&
                      detail.trackingNumber!.isNotEmpty) ||
                  (detail.storeName.isNotEmpty)) ...[
                if (detail.storeName.isNotEmpty)
                  Text(
                    "Seller: ${detail.storeName}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                if (detail.trackingNumber != null &&
                    detail.trackingNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      "Tracking ID: ${detail.trackingNumber}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                Divider(height: 24, color: colors.outlineVariant),
              ],

              // Dynamic Status Timeline
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    "No tracking status updates available yet.",
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isLast = index == history.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Timeline Indicators (Dot + Vertical Line)
                          Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Right Status Detail Text
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Heading
                                  Text(
                                    item.toStatus,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),

                                  if (item.notes != null &&
                                      item.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.notes!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],

                                  if (item.changedByName != null &&
                                      item.changedByName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "Updated by: ${item.changedByName}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Timestamp
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
