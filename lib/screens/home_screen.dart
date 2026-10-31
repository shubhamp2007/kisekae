import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/notification_service.dart';
import 'package:kisekae/screens/addresses.dart';
import 'package:kisekae/screens/categories.dart';
import 'package:kisekae/screens/products_list.dart';
import 'package:kisekae/screens/season_sale_screen.dart';
import 'package:kisekae/screens/subcategories/kids.dart';
import 'package:kisekae/screens/subcategories/mens.dart';
import 'package:kisekae/screens/subcategories/womens.dart';
import 'package:kisekae/screens/wishlist_screen.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/profile_details.dart';
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

  final List<String> brandImages = [
    'assets/images/brands/deals1.png',
    'assets/images/brands/deals2.png',
    'assets/images/brands/deals3.png',
  ];

  @override
  void initState() {
    super.initState();
    _subscription = NotificationService().onTap.listen(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService().consumePendingDeepLink();
      if (pending != null) _handleDeepLink(pending);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
    return Material(
      color: const Color(0xFF8B2E3E),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WishlistScreen()));
        },
        child: const SizedBox(
          height: 37,
          width: 37,
          child: Icon(Icons.favorite, color: Color(0xFFDBBEC3), size: 22),
        ),
      ),
    );
  }

  void _openSeasonSale() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SeasonSaleScreen()));
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    "KISEKAE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7D2938),
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
                  GestureDetector(
                    onTap: _openSeasonSale,
                    child: Container(
                      width: 370,
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFE5DDD3),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/banner.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Brands To Explore",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
                        'Best Deals',
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
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFDBBEC3),
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
