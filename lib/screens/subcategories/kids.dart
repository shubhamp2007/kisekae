import "package:flutter/material.dart";
import "package:kisekae/screens/products_list.dart";
import "package:kisekae/widgets/bottom_bar.dart";
import "package:kisekae/widgets/searchbar.dart";

class KidsSubCategoriesScreen extends StatefulWidget {
  const KidsSubCategoriesScreen({super.key});

  @override
  State<KidsSubCategoriesScreen> createState() =>
      _KidsSubCategoriesScreenState();
}

class _KidsSubCategoriesScreenState extends State<KidsSubCategoriesScreen> {
  static const List<String> _spotlightImages = [
    'assets/images/deals/7.jpg',
    'assets/images/deals/8.jpg',
    'assets/images/deals/9.jpg',
  ];

  static const String _festiveBanner = 'assets/images/banners/9.jpg';

  static const List<String> _festiveCards = [
    'assets/images/banners/10.jpg',
    'assets/images/banners/11.jpg',
    'assets/images/banners/12.jpg',
  ];

  static const List<String> _brandImages = [
    'assets/images/brands/7.jpg',
    'assets/images/brands/8.jpg',
    'assets/images/brands/9.jpg',
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
    final colors = Theme.of(context).colorScheme;
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
              border: Border.all(color: colors.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: colors.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "Kids' fashion",
          style: TextStyle(fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/25.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Girls',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/26.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Boys',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/21.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Casuals',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/27.jpg',
                        alignment: Alignment(0, -0.5),
                        label: 'Partywear',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/28.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Jeans',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/29.jpg',
                        alignment: Alignment.topCenter,
                        label: 'Ethinic wear',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/30.jpg',
                        alignment: Alignment(0, -0.25),
                        label: 'Jacket',
                      ),
                      _CategoryImage(
                        imageUrl: 'assets/images/clothes/31.jpg',
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
    final colors = Theme.of(context).colorScheme;
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
            // "Try now" band: intentionally a fixed brand gradient with light text
            GestureDetector(
              onTap: _openProducts,
              child: Container(
                width: double.infinity,
                height: _barHeight,
                padding: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 2.2,
                    colors: [
                      Color(0xFF8B2E3E),
                      Color(0xFF5E1F2A),
                      Color(0xFF311016),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: const Text(
                  'TRY NOW WITH AR',
                  style: TextStyle(
                    color: Color(0xFFF3E9EA),
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
                        border: Border.all(color: colors.onSurface, width: 1.5),
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
    final colors = Theme.of(context).colorScheme;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: colors.outlineVariant,
        child: Icon(Icons.image, size: 36, color: colors.outline),
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
    final colors = Theme.of(context).colorScheme;
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
