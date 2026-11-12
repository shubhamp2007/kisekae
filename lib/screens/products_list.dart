import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/product_detail.dart';
import 'package:kisekae/screens/filter_screen.dart';
import 'package:kisekae/screens/product_screen.dart';
import 'package:kisekae/services/buyer_product.dart';

import 'package:kisekae/services/wishlist_service.dart';

class FilterChipData {
  final String label;
  final String? ordering;
  final String? category;
  final bool? inStock;
  final double? maxPrice;

  const FilterChipData({
    required this.label,
    this.ordering,
    this.category,
    this.inStock,
    this.maxPrice,
  });
}

class ProductListScreen extends StatefulWidget {
  final String? initialQuery;

  const ProductListScreen({super.key, this.initialQuery});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
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
  String _searchQuery = '';

  final List<FilterChipData> _apiFilters = const [
    FilterChipData(label: "Top Rated", ordering: "top_rated"),
    FilterChipData(label: "In Stock", inStock: true),
    FilterChipData(label: "Tops", category: "Top"),
    FilterChipData(label: "One-Piece", category: "ONE_PIECE"),
    FilterChipData(label: "Newest", ordering: "newest"),
    FilterChipData(label: "Under ₹500", maxPrice: 500.0),
  ];

  FilterChipData? _selectedFilter;
  ProductFilters _filters = const ProductFilters();

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _searchQuery = initialQuery;
      _searchController.text = initialQuery;
    }
    _scrollController.addListener(_onScroll);
    _fetchProducts();
    _loadWishlist();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCancelToken?.cancel("Screen disposed");
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
    _searchCancelToken?.cancel("New search request initiated");
    _searchCancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = false;
      _currentPage = 1;
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

      if (mounted) {
        setState(() {
          _products = response.results;
          _totalCount = response.count;
          _currentPage = 1;
          _hasMore = response.next != null && response.results.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
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
      setState(() => _isLoadingMore = false);
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
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = colors.surface;
    final primaryColor = colors.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
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
                    hintText: "EXPLORE YOUR STYLE",
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
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appColors.border),
              ),
              child: IconButton(
                icon: Icon(Icons.tune, color: colors.onSurface, size: 20),
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final result = await Navigator.of(context)
                      .push<ProductFilters>(
                        MaterialPageRoute(
                          builder: (_) =>
                              FilterScreen(initialFilters: _filters),
                        ),
                      );
                  if (result == null || !mounted) return;
                  setState(() => _filters = result);
                  _fetchProducts();
                },
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),

            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _apiFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final filter = _apiFilters[index];
                  final isSelected = _selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedFilter = isSelected ? null : filter;
                      });
                      _fetchProducts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : context.appColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : context.appColors.border,
                        ),
                      ),
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          color: isSelected
                              ? colors.onPrimary
                              : colors.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchProducts,
                      color: primaryColor,
                      child: _products.isEmpty
                          ? CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      "No products found",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.68,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final product = _products[index];
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductDetailsScreen(
                                                  productId: product.id,
                                                ),
                                          ),
                                        );
                                      },
                                      child: _buildProductCard(product),
                                    );
                                  }, childCount: _products.length),
                                ),
                                if (_isLoadingMore)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
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
                                  )
                                else
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 20),
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductDetail product) {
    final colors = Theme.of(context).colorScheme;
    final isWishlisted = _wishlistedProductIds.contains(product.id);
    final imageUrl = product.imageUrl ?? product.thumbnail ?? '';
    final hasStore = product.storeName.trim().isNotEmpty;

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
                right: 8,
                child: GestureDetector(
                  onTap: () => _toggleWishlist(product),
                  child: Container(
                    height: 26,
                    width: 26,
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
                  fontSize: 15,
                  fontWeight: hasStore ? FontWeight.w500 : FontWeight.w400,
                  color: hasStore ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 2),
            Text(
              product.averageRating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 14,
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
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.onSurfaceVariant,
            ),
          ),
        Text(
          "₹${double.tryParse(product.price)?.toInt() ?? product.price}",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}
