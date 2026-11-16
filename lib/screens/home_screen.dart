import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/notification_service.dart';
import 'package:kisekae/models/buyer_seasonal_sale.dart';
import 'package:kisekae/screens/addresses.dart';
import 'package:kisekae/screens/categories.dart';
import 'package:kisekae/screens/products_list.dart';
import 'package:kisekae/screens/season_sale_screen.dart';
import 'package:kisekae/screens/subcategories/kids.dart';
import 'package:kisekae/screens/subcategories/mens.dart';
import 'package:kisekae/screens/subcategories/womens.dart';
import 'package:kisekae/screens/wishlist_screen.dart';
import 'package:kisekae/services/buyer_seasonal_service.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/widgets/best_deals.dart';
import 'package:kisekae/widgets/bottom_bar.dart';
import 'package:kisekae/widgets/searchbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _subscription;
  final SeasonalSales _seasonalSalesRepo = SeasonalSales();
  final PageController _bannerPageController = PageController();

  List<SeasonalSale> _ongoingSales = [];
  int _currentBannerIndex = 0;

  final List<String> brandImages = [
    'assets/images/brands/deals1.png',
    'assets/images/brands/deals2.png',
    'assets/images/brands/deals3.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadOngoingSales();
    _subscription = NotificationService().onTap.listen(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService().consumePendingDeepLink();
      if (pending != null) _handleDeepLink(pending);
    });
  }

  Future<void> _loadOngoingSales() async {
    try {
      final sales = await _seasonalSalesRepo.getSales();
      if (!mounted) return;
      final liveSales = sales.where((s) => s.isLive).toList();
      setState(() {
        _ongoingSales = liveSales.isNotEmpty ? liveSales : sales;
      });
    } catch (e) {
      debugPrint('Failed to load ongoing seasonal sales: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    final deepLink = data['deep_link'] as String?;
    if (deepLink == null) return;

    final uri = Uri.tryParse(deepLink);
    if (uri == null || uri.scheme != 'kisekae') return;

    if (uri.host == 'orders') {
      final rawId = uri.pathSegments.firstOrNull;
      final orderId = int.tryParse(rawId ?? '');
      if (orderId != null) {
        navigatorKey.currentState?.pushNamed('/orders/$orderId');
      }
    } else if (uri.host == 'tryon') {
      final requestId = uri.pathSegments.firstOrNull;
      if (requestId != null && requestId.isNotEmpty) {
        navigatorKey.currentState?.pushNamed('/tryon/$requestId');
      }
    }
  }

  Widget _wishlistButton() {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WishlistScreen()));
        },
        child: SizedBox(
          height: 37,
          width: 37,
          child: Icon(
            Icons.favorite,
            color: colors.onPrimary.withValues(alpha: 0.8),
            size: 22,
          ),
        ),
      ),
    );
  }

  void _openSeasonSale(SeasonalSale? sale) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => sale != null
            ? SeasonSaleScreen(
                seasonalSale: sale,
                title: sale.title,
                subtitle: sale.description,
              )
            : const SeasonSaleScreen(),
      ),
    );
  }

  Widget _buildSaleBannerCarousel(ColorScheme colors) {
    if (_ongoingSales.isEmpty) {
      return GestureDetector(
        onTap: () => _openSeasonSale(null),
        child: Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: colors.outlineVariant, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/images/banner.png', fit: BoxFit.cover),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: _ongoingSales.length,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final sale = _ongoingSales[index];
              final discountNum = double.tryParse(sale.discountPercentage) ?? 0;
              final discountText = discountNum == discountNum.roundToDouble()
                  ? '${discountNum.toInt()}% OFF'
                  : '$discountNum% OFF';
              return Padding(
                padding: EdgeInsets.only(
                  right: _ongoingSales.length > 1 ? 6.0 : 0,
                ),
                child: GestureDetector(
                  onTap: () => _openSeasonSale(sale),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          sale.bannerImage.isNotEmpty
                              ? Image.network(
                                  sale.bannerImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/banner.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/banner.png',
                                  fit: BoxFit.cover,
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_ongoingSales.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_ongoingSales.length, (index) {
              final isSelected = index == _currentBannerIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 118,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "KISEKAE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: colors.primary,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressesScreen(),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  children: [
                    Icon(Icons.place_rounded, size: 18),
                    SizedBox(width: 2),
                    Text(
                      "HOME",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: KisekaeSearchBar()),
                  const SizedBox(width: 10),
                  _wishlistButton(),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildSaleBannerCarousel(colors),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoriesScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/4.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Women',
                        screen: WomensSubCategoriesScreen(),
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/7.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Men',
                        screen: MensSubCategoriesScreen(),
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/5.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Kids',
                        screen: KidsSubCategoriesScreen(),
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/6.jpg',
                        alignment: Alignment(0, -0.5),
                        label: 'Formals',
                        screen: ProductListScreen(initialQuery: "Formals"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.4,
                  colors: [
                    Color(0xFF8B2E3E),
                    Color(0xFF5E1F2A),
                    Color(0xFF481820),
                    Color(0xFF311016),
                  ],
                  stops: [0.2067, 0.6058, 0.8173, 1.0],
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Flat ₹500 Off',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "USE CODE :",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "FEST500",
                        style: TextStyle(
                          color: Color(0xFFD9601A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "T&C Apply",
                        style: TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Brands To Explore",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/brands/deals1.png',
                          width: 110,
                          height: 170,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/brands/deals3.png',
                          width: 150,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/brands/deals2.png',
                          width: 110,
                          height: 170,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recommended for you',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProductListScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const FeaturedProductsRow(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  final String imageUrl;
  final Alignment alignment;
  final String label;
  final Widget screen;

  const _CategoryImage({
    required this.imageUrl,
    required this.alignment,
    required this.label,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors.primary.withValues(alpha: 0.3),
              child: ClipOval(
                child: Image.asset(
                  imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  alignment: alignment,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
