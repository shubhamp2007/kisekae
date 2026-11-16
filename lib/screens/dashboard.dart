import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/advertising.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/dashboard_model.dart';
import 'package:kisekae/screens/add_product.dart';
import 'package:kisekae/screens/advertising_screen.dart';
import 'package:kisekae/screens/analytics_screen.dart';
import 'package:kisekae/screens/multiple_stores.dart';
import 'package:kisekae/screens/store_order.dart';
import 'package:kisekae/screens/promotion_screen.dart';
import 'package:kisekae/services/analytics.dart';
import 'package:kisekae/services/seller_product.dart';
import 'package:kisekae/widgets/seller_bottom_bar.dart';

class SellerDashboardScreen extends StatefulWidget {
  final int storeId;

  const SellerDashboardScreen({super.key, required this.storeId});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _currentIndex = 0;
  final HandleProduct _productService = HandleProduct();

  Color get _widgetBgColor => context.appColors.card;

  final Analytics _analytics = Analytics();
  final CancelToken _cancelToken = CancelToken();
  DashboardMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void dispose() {
    _cancelToken.cancel("SellerDashboardScreen disposed");
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadMetrics() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));

    try {
      final metrics = await _analytics.getStoreDashboardMetrics(
        storeId: widget.storeId,
        fromDate: _formatDate(from),
        toDate: _formatDate(now),
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() => _metrics = metrics);
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      final message = e is ApiException
          ? e.message
          : 'Could not load dashboard data';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _money(double value, String currency) {
    final number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    return '$symbol$number';
  }

  String _display(String Function(DashboardMetrics metrics) pick) {
    final metrics = _metrics;
    if (metrics == null || metrics.totalOrders == 0) return '–';
    return pick(metrics);
  }

  void _openAdvertisement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvertisementScreen(
          storeId: widget.storeId,
          loadStoreProducts: () async {
            final products = await _productService.getStoreProducts(
              storeId: widget.storeId,
            );
            return products
                .map(
                  (p) => PromotableProduct(
                    id: p.id,
                    name: p.name,
                    price: double.tryParse(p.price) ?? 0,
                  ),
                )
                .toList();
          },
        ),
      ),
    );
  }

  void _openPromotions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PromotionsScreen(
          storeId: widget.storeId,
          loadStoreProducts: () async {
            final products = await _productService.getStoreProducts(
              storeId: widget.storeId,
            );
            return products
                .map(
                  (p) => PromotableProduct(
                    id: p.id,
                    name: p.name,
                    price: double.tryParse(p.price) ?? 0,
                  ),
                )
                .toList();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    final horizontalPadding = size.width * (20 / 360);
    final verticalPadding = size.height * (16 / 840);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const MultipleStoresScreen(),
              ),
              (route) => false,
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: colorScheme.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "KISEKAE",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: colorScheme.primary,
              fontFamily: 'serif',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreBanner(size, colorScheme),
              SizedBox(height: size.height * (20 / 840)),
              _buildTotalSalesCard(size, colorScheme),
              SizedBox(height: size.height * (24 / 840)),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: size.width * (20 / 360),
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: size.height * (12 / 840)),
              _buildQuickActionsRow(context, size, colorScheme),
              SizedBox(height: size.height * (20 / 840)),
              _buildStatsGrid(size, colorScheme),
              SizedBox(height: size.height * (16 / 840)),
              _advertisementRedirectCard(size, colorScheme, _openAdvertisement),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SellerBottomBar(
        storeId: widget.storeId,
        selectedIndex: _currentIndex,
        onItemTapped: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildStoreBanner(Size size, ColorScheme colorScheme) {
    final bannerWidth = size.width * (320 / 360);
    final bannerHeight = size.height * (182 / 840);

    return Center(
      child: Container(
        width: bannerWidth,
        height: bannerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _widgetBgColor,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/StoreBanner.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSalesCard(Size size, ColorScheme colorScheme) {
    final cardWidth = size.width * (320 / 360);
    final cardHeight = size.height * (88 / 840);

    return Center(
      child: Container(
        width: cardWidth,
        height: cardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _widgetBgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(
                  _display((m) => _money(m.totalRevenue, m.currency)),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(
    BuildContext context,
    Size size,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickActionItem(
          size,
          colorScheme,
          'assets/icons/addproducts.svg',
          'Add\nProducts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddProductScreen(storeId: widget.storeId),
              ),
            );
          },
        ),
        _buildQuickActionItem(
          size,
          colorScheme,
          'assets/icons/vieworders.svg',
          'View\nOrders',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrdersScreen(storeId: widget.storeId),
              ),
            );
          },
        ),
        _buildQuickActionItem(
          size,
          colorScheme,
          'assets/icons/promotions.svg',
          'Promotions',
          onTap: _openPromotions,
        ),
        _buildQuickActionItem(
          size,
          colorScheme,
          'assets/icons/analytics.svg',
          'Analytics',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsScreen(storeId: widget.storeId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(
    Size size,
    ColorScheme colorScheme,
    String assetPath,
    String label, {
    VoidCallback? onTap,
  }) {
    final buttonWidth = size.width * (68 / 360);
    final buttonHeight = size.height * (68 / 840);
    final labelHeight = size.height * (32 / 840);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: buttonWidth,
            height: buttonHeight,
            decoration: BoxDecoration(
              color: _widgetBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: buttonWidth,
            height: labelHeight,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _svgIcon(ColorScheme colorScheme, String assetPath) {
    return SvgPicture.asset(
      assetPath,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
    );
  }

  Widget _buildStatsGrid(Size size, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              size,
              colorScheme,
              'Total Orders',
              _display((m) => m.totalOrders.toString()),
              _svgIcon(colorScheme, 'assets/icons/vieworders.svg'),
            ),
            _buildStatCard(
              size,
              colorScheme,
              'Units Sold',
              _display((m) => m.totalUnitsSold.toString()),
              _svgIcon(colorScheme, 'assets/icons/products.svg'),
            ),
          ],
        ),
        SizedBox(height: size.height * (16 / 840)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              size,
              colorScheme,
              'Avg. Order Value',
              _display((m) => _money(m.averageOrderValue, m.currency)),
              Icon(
                Icons.payments_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
            ),
            _buildStatCard(
              size,
              colorScheme,
              'Cancellation Rate',
              _display((m) => '${m.cancellationRate.toStringAsFixed(1)}%'),
              Icon(Icons.cancel_outlined, size: 22, color: colorScheme.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    Size size,
    ColorScheme colorScheme,
    String title,
    String value,
    Widget icon,
  ) {
    final cardWidth = size.width * (152 / 360);
    final cardHeight = size.height * (88 / 840);

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _widgetBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              icon,
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advertisementRedirectCard(
    Size size,
    ColorScheme colorScheme,
    VoidCallback onTap,
  ) {
    final cardWidth = size.width * (320 / 360);
    final cardHeight = size.height * (65 / 840);

    return InkWell(
      onTap: onTap,
      child: Center(
        child: Container(
          width: cardWidth,
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _widgetBgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.cell_tower, size: 22, color: colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Advertisement",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Create campaigns to reach more buyer",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 22, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
