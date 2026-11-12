import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/product_detail.dart';
import 'package:kisekae/models/seasonal_sale_seller.dart';
import 'package:kisekae/screens/filter_screen.dart';
import 'package:kisekae/screens/product_screen.dart';
import 'package:kisekae/screens/wishlist_screen.dart';
import 'package:kisekae/services/buyer_product.dart';
import 'package:kisekae/services/wishlist_service.dart';

class SeasonSaleFilterChipData {
  final String label;
  final String? ordering;
  final String? category;
  final bool? inStock;
  final double? maxPrice;

  const SeasonSaleFilterChipData({
    required this.label,
    this.ordering,
    this.category,
    this.inStock,
    this.maxPrice,
  });
}

class SeasonSaleScreen extends StatefulWidget {
  final String? bannerAsset;
  final String? bannerImageUrl;
  final String? title;
  final String? subtitle;
  final SeasonalSale? seasonalSale;

  const SeasonSaleScreen({
    super.key,
    this.bannerAsset = 'assets/images/banner.png',
    this.bannerImageUrl,
    this.title = 'SEASON SALE',
    this.subtitle = 'Limited Time Exclusive Deals & Offers',
    this.seasonalSale,
  });

  @override
  State<SeasonSaleScreen> createState() => _SeasonSaleScreenState();
}

class _SeasonSaleScreenState extends State<SeasonSaleScreen> {
  final Product _productService = Product();
  final WishlistService _wishlistService = WishlistService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CancelToken? _searchCancelToken;

  List<ProductDetail> _products = [];
  final Set<int> _wishlistedProductIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 1;
  int _totalCount = 0;
  String? _errorMessage;
  String _searchQuery = '';

  Color get backgroundColor => Theme.of(context).colorScheme.surface;
  Color get primaryColor => Theme.of(context).colorScheme.primary;

  final List<SeasonSaleFilterChipData> _saleFilters = const [
    SeasonSaleFilterChipData(label: 'All Deals'),
    SeasonSaleFilterChipData(label: 'Under ₹500', maxPrice: 500.0),
    SeasonSaleFilterChipData(label: 'Under ₹1000', maxPrice: 1000.0),
    SeasonSaleFilterChipData(label: 'Top Rated', ordering: 'top_rated'),
    SeasonSaleFilterChipData(label: 'Tops', category: 'Top'),
    SeasonSaleFilterChipData(label: 'One-Piece', category: 'ONE_PIECE'),
    SeasonSaleFilterChipData(label: 'In Stock', inStock: true),
    SeasonSaleFilterChipData(label: 'New Arrivals', ordering: 'newest'),
  ];

  SeasonSaleFilterChipData? _selectedFilter;
  ProductFilters _filters = const ProductFilters();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchProducts();
    _loadWishlist();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCancelToken?.cancel('Screen disposed');
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (_products.isNotEmpty && currentScroll >= (maxScroll - 250)) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadWishlist() async {
    try {
      final items = await _wishlistService.getWishlistItems();
      if (!mounted) return;
      setState(() {
        _wishlistedProductIds.clear();
        for (final item in items) {
          _wishlistedProductIds.add(item.product.id);
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    _searchCancelToken?.cancel('New search request initiated');
    _searchCancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = false;
      _currentPage = 1;
      _errorMessage = null;
    });

    try {
      final response = await _productService.getProducts(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ordering: _selectedFilter?.ordering ?? _filters.ordering,
        category: _selectedFilter?.category,
        inStock: _selectedFilter?.inStock,
        size: _filters.size,
        color: _filters.color,
        minPrice: _filters.minPrice,
        maxPrice: _selectedFilter?.maxPrice ?? _filters.maxPrice,
        page: 1,
        cancelToken: _searchCancelToken,
      );

      if (!mounted) return;
      setState(() {
        _products = response.results;
        _totalCount = response.count;
        _currentPage = 1;
        _hasMore = response.next != null && response.results.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load sale products. Please try again.';
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _productService.getProducts(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ordering: _selectedFilter?.ordering ?? _filters.ordering,
        category: _selectedFilter?.category,
        inStock: _selectedFilter?.inStock,
        size: _filters.size,
        color: _filters.color,
        minPrice: _filters.minPrice,
        maxPrice: _selectedFilter?.maxPrice ?? _filters.maxPrice,
        page: nextPage,
        cancelToken: _searchCancelToken,
      );

      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _products.addAll(response.results);
        _totalCount = response.count;
        _hasMore = response.next != null && response.results.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _toggleWishlist(ProductDetail product) async {
    final productId = product.id;
    final isWishlisted = _wishlistedProductIds.contains(productId);

    setState(() {
      if (isWishlisted) {
        _wishlistedProductIds.remove(productId);
      } else {
        _wishlistedProductIds.add(productId);
      }
    });

    try {
      if (!isWishlisted) {
        await _wishlistService.addToWishlist(productId: productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} added to wishlist'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _wishlistService.removeWishlistItem(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} removed from wishlist'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isWishlisted) {
            _wishlistedProductIds.add(productId);
          } else {
            _wishlistedProductIds.remove(productId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wishlist update failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchProducts,
        color: primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildBannerSection()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            SliverToBoxAdapter(child: _buildSummaryBar()),
            _buildProductsContent(),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      toolbarHeight: 70,
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
            size: 18,
            color: colors.onSurface,
          ),
        ),
      ),
      titleSpacing: 0,
      title: Container(
        height: 46,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: colors.onSurface, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: colors.onSurface),
                cursorColor: colors.primary,
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus();
                  _searchQuery = value.trim();
                  _fetchProducts();
                },
                decoration: InputDecoration(
                  hintText: 'SEARCH SEASON SALE',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _searchController.clear();
                  _searchQuery = '';
                  _fetchProducts();
                },
                child: Icon(
                  Icons.clear,
                  color: colors.onSurfaceVariant,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
      actions: [
        Container(
          height: 46,
          width: 46,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.border),
          ),
          child: IconButton(
            icon: Icon(Icons.tune, color: colors.onSurface, size: 20),
            onPressed: () async {
              FocusScope.of(context).unfocus();
              final result = await Navigator.of(context).push<ProductFilters>(
                MaterialPageRoute(
                  builder: (_) => FilterScreen(initialFilters: _filters),
                ),
              );
              if (result == null || !mounted) return;
              setState(() => _filters = result);
              _fetchProducts();
            },
          ),
        ),
        Container(
          height: 46,
          width: 46,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.border),
          ),
          child: IconButton(
            icon: Icon(Icons.favorite_border, color: primaryColor, size: 20),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WishlistScreen()));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBannerSection() {
    final colors = Theme.of(context).colorScheme;
    final sale = widget.seasonalSale;
    final hasRemoteBanner =
        (widget.bannerImageUrl != null && widget.bannerImageUrl!.isNotEmpty) ||
        (sale?.bannerImage != null && sale!.bannerImage!.isNotEmpty);
    final remoteUrl = widget.bannerImageUrl ?? sale?.bannerImage;

    final bannerTitle = sale != null && sale.title.isNotEmpty
        ? sale.title
        : (widget.title ?? 'SEASON SALE');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasRemoteBanner
                      ? Image.network(
                          remoteUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            widget.bannerAsset ?? 'assets/images/banner.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          widget.bannerAsset ?? 'assets/images/banner.png',
                          fit: BoxFit.cover,
                        ),
                  if (sale?.timingText.isNotEmpty ?? false)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      // kept dark with white text on purpose: it sits on the banner image
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sale!.timingText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bannerTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sale?.subtitle ??
                    (widget.subtitle ?? 'Exclusive Seasonal Discounts'),
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _saleFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _saleFilters[index];
            final isAllDeals = filter.label == 'All Deals';
            final isSelected = isAllDeals
                ? (_selectedFilter == null)
                : (_selectedFilter == filter);

            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  if (isAllDeals) {
                    _selectedFilter = null;
                  } else {
                    _selectedFilter = isSelected ? null : filter;
                  }
                });
                _fetchProducts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : context.appColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryColor : context.appColors.border,
                  ),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isLoading
                ? 'Loading items...'
                : '${_totalCount > 0 ? _totalCount : _products.length} Items Available',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          if (!_filters.isEmpty ||
              _selectedFilter != null ||
              _searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = null;
                  _filters = const ProductFilters();
                });
                _fetchProducts();
              },
              child: Text(
                'Reset Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsContent() {
    final colors = Theme.of(context).colorScheme;

    if (_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: primaryColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _fetchProducts,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: colors.onPrimary,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: colors.outline,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No products found in this sale',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try clearing your filters or search keywords',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = null;
                    _filters = const ProductFilters();
                  });
                  _fetchProducts();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  foregroundColor: primaryColor,
                ),
                child: const Text('View All Deals'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = _products[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(productId: product.id),
                ),
              );
            },
            child: _buildProductCard(product),
          );
        }, childCount: _products.length),
      ),
    );
  }

  Widget _buildProductCard(ProductDetail product) {
    final colors = Theme.of(context).colorScheme;
    final isWishlisted = _wishlistedProductIds.contains(product.id);
    final imageUrl = product.imageUrl ?? product.thumbnail ?? '';
    final hasStore = product.storeName.trim().isNotEmpty;

    final priceDouble = double.tryParse(product.price) ?? 0;
    final compareDouble = product.compareAtPrice != null
        ? double.tryParse(product.compareAtPrice!)
        : null;

    int? discountPercent;
    if (compareDouble != null && compareDouble > priceDouble) {
      discountPercent = (((compareDouble - priceDouble) / compareDouble) * 100)
          .round();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: colors.outlineVariant,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/clothes/4.jpg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        imageUrl.isNotEmpty
                            ? imageUrl
                            : 'assets/images/clothes/4.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.image,
                            size: 40,
                            color: colors.outline,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    discountPercent != null ? '$discountPercent% OFF' : 'SALE',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _toggleWishlist(product),
                  child: Container(
                    height: 28,
                    width: 28,
                    // kept white on purpose: the heart icons are image assets
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        isWishlisted
                            ? 'assets/icons/wishlist.png'
                            : 'assets/icons/wishlist2.png',
                        width: 26,
                        height: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                hasStore ? product.storeName : product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasStore ? FontWeight.w500 : FontWeight.w400,
                  color: hasStore ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.star, size: 15, color: Colors.amber),
            const SizedBox(width: 2),
            Text(
              product.averageRating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        if (hasStore)
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: colors.onSurfaceVariant,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₹${priceDouble.toInt()}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            if (compareDouble != null && compareDouble > priceDouble) ...[
              const SizedBox(width: 6),
              Text(
                '₹${compareDouble.toInt()}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.mutedText,
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
