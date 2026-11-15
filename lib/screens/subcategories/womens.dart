import "package:flutter/material.dart";
import "package:kisekae/core/notifications/theme/app_theme.dart";
import "package:kisekae/screens/products_list.dart";
import "package:kisekae/widgets/bottom_bar.dart";
import "package:kisekae/widgets/searchbar.dart";

class WomensSubCategoriesScreen extends StatefulWidget {
  const WomensSubCategoriesScreen({super.key});

  @override
  State<WomensSubCategoriesScreen> createState() =>
      _WomensSubCategoriesScreenState();
}

class _WomensSubCategoriesScreenState extends State<WomensSubCategoriesScreen> {
  static const List<String> _spotlightImages = [
    'assets/images/deals/1.jpg',
    'assets/images/deals/2.jpg',
    'assets/images/deals/3.jpg',
  ];

  static const String _festiveBanner = 'assets/images/banners/1.jpg';

  static const List<String> _festiveCards = [
    'assets/images/banners/2.jpg',
    'assets/images/banners/3.jpg',
    'assets/images/banners/4.jpg',
  ];

  static const List<String> _brandImages = [
    'assets/images/brands/1.jpg',
    'assets/images/brands/2.jpg',
    'assets/images/brands/3.jpg',
  ];

  static const double _bannerHeight = 320;
  static const double _festiveCardsHeight = 162;
  static const double _festiveCardsOverlap = 55;
  static const double _bannerToBarGap = 85;
  static const double _barHeight = 100;

  final PageController _spotlightController = PageController(
    viewportFraction: 0.58,
    initialPage: 1,
  );

  final PageController _festiveController = PageController(
    viewportFraction: 0.41,
    initialPage: 1,
  );

  int _spotlightPage = 1;
  int _festivePage = 1;

  @override
  void dispose() {
    _spotlightController.dispose();
    _festiveController.dispose();
    super.dispose();
  }

  void _openProducts() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProductListScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: context.cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: context.cs.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Women's fashion",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.cs.onSurface,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(58),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: KisekaeSearchBar(),
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
                  const SizedBox(height: 24),
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: context.cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/11.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Tops',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/12.jpg',
                        alignment: Alignment.topCenter,
                        label: 'T-shirt',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/13.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Dress',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/14.jpg',
                        alignment: Alignment(0, -0.5),
                        label: 'Formals',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/15.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Jeans',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/16.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Ethinic wear',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/17.jpg',
                        alignment: Alignment(0, -0.25),
                        label: 'Jacket',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/18.jpg',
                        alignment: Alignment(0, -0.5),
                        label: 'Winter wear',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const _SectionTitle('Spotlight Steals'),
                  const SizedBox(height: 8),
                  _buildSpotlight(),
                  const SizedBox(height: 30),
                  const _SectionTitle('Festive Mood'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildFestive(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 25),
                  const _SectionTitle('Shop by Brands'),
                  const SizedBox(height: 8),
                  _buildBrands(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(),
    );
  }

  Widget _scaledPage({
    required bool selected,
    required double height,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1.0 : 0.87),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Align(
          alignment: Alignment.center,
          child: SizedBox(height: height * scale, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildSpotlight() {
    const double maxHeight = 170;

    return SizedBox(
      height: maxHeight,
      child: PageView.builder(
        controller: _spotlightController,
        itemCount: _spotlightImages.length,
        onPageChanged: (i) => setState(() => _spotlightPage = i),
        itemBuilder: (context, i) {
          return _scaledPage(
            selected: i == _spotlightPage,
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _tapImage(_spotlightImages[i], radius: 20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFestive() {
    final cs = context.cs;
    final isDark = cs.brightness == Brightness.dark;
    final gradientColors = [
      cs.primary,
      Color.lerp(cs.primary, Colors.black, 0.35)!,
      Color.lerp(cs.primary, Colors.black, 0.65)!,
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _openProducts,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: _bannerHeight,
                    child: _asset(_festiveBanner),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _bannerToBarGap),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: _openProducts,
              child: Container(
                width: double.infinity,
                height: _barHeight,
                padding: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 2.2,
                    colors: gradientColors,
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: Text(
                  'TRY NOW WITH AR',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: _bannerHeight - _festiveCardsOverlap,
          left: 16,
          right: 16,
          height: _festiveCardsHeight,
          child: PageView.builder(
            controller: _festiveController,
            itemCount: _festiveCards.length,
            onPageChanged: (i) => setState(() => _festivePage = i),
            itemBuilder: (context, i) {
              return _scaledPage(
                selected: i == _festivePage,
                height: _festiveCardsHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: _openProducts,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          // Dark frame in light mode, softer outline in dark
                          // mode (a near-black border would vanish on 121212).
                          color: isDark ? cs.outline : cs.onSurface,
                          width: 1.5,
                        ),
                      ),
                      child: _asset(_festiveCards[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrands() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _tapImage(_brandImages[0], height: 262)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _tapImage(_brandImages[1], height: 125),
              const SizedBox(height: 12),
              _tapImage(_brandImages[2], height: 125),
            ],
          ),
        ),
      ],
    );
  }

  Widget _asset(String path) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: context.cs.surfaceContainerHighest,
        child: Icon(Icons.image, size: 36, color: context.cs.onSurfaceVariant),
      ),
    );
  }

  Widget _tapImage(String path, {double? height, double radius = 20}) {
    return GestureDetector(
      onTap: _openProducts,
      child: Container(
        width: double.infinity,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        child: _asset(path),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: context.cs.onSurface,
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  final String imageUrl;
  final Alignment alignment;
  final String label;
  const _CategoryImage({
    required this.imageUrl,
    required this.alignment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductListScreen(
                initialQuery: label.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ''),
              ),
            ),
          );
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: Color.alphaBlend(
                cs.primary.withAlpha(51),
                cs.surface,
              ),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
