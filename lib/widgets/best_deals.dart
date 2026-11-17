import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/models/product_detail.dart';
import 'package:kisekae/screens/product_screen.dart';
import 'package:kisekae/services/buyer_product.dart';
import 'package:kisekae/widgets/product_card.dart';

class FeaturedProductsRow extends StatefulWidget {
  final int count;

  const FeaturedProductsRow({super.key, this.count = 2});

  @override
  State<FeaturedProductsRow> createState() => _FeaturedProductsRowState();
}

class _FeaturedProductsRowState extends State<FeaturedProductsRow> {
  static const double _gap = 12;
  static const int _pageSize = 20;
  static const double _loadMoreThreshold = 200;

  final Product _productService = Product();
  final CancelToken _cancelToken = CancelToken();
  final ScrollController _scrollController = ScrollController();

  final List<ProductDetail> _products = [];
  final Set<int> _seenIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _cancelToken.cancel('Widget disposed');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _addProducts(List<ProductDetail> items) {
    for (final product in items) {
      if (_seenIds.add(product.id)) _products.add(product);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _productService.getRecommendedProducts(
        page: 1,
        pageSize: _pageSize,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _products.clear();
        _seenIds.clear();
        _addProducts(response.adProducts);
        _addProducts(response.results);
        _page = 1;
        _hasMore = response.hasNext;
        _isLoading = false;
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await _productService.getRecommendedProducts(
        page: nextPage,
        pageSize: _pageSize,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _addProducts(response.results);
        _page = nextPage;
        _hasMore = response.hasNext;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _openProduct(ProductDetail product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: product.id),
      ),
    );
  }

  double _cardWidth(double maxWidth) {
    final totalGap = _gap * (widget.count - 1);
    return (maxWidth - totalGap) / widget.count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_hasError) return _buildError();
    if (_products.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _cardWidth(constraints.maxWidth);

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _products.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(width: cardWidth, child: _buildCard(_products[i])),
              ],
              if (_isLoadingMore) ...[
                const SizedBox(width: _gap),
                _buildLoadMoreIndicator(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(ProductDetail product) {
    final imageUrl = product.imageUrl ?? product.thumbnail ?? '';
    final price = (double.tryParse(product.price) ?? 0).toInt();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(product),
      child: ProductCard(
        imageUrl: imageUrl,
        title: product.name,
        storeName: product.storeName,
        rating: product.averageRating,
        price: price,
        alignment: const Alignment(0, -0.75),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 140,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 0; i < widget.count; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 215,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load products'),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
