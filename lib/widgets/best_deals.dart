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
  final Product _productService = Product();
  final CancelToken _cancelToken = CancelToken();

  List<ProductDetail> _products = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken.cancel('Widget disposed');
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _productService.getProducts(
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _products = response.results.take(widget.count).toList();
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

  void _openProduct(ProductDetail product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_hasError) return _buildError();
    if (_products.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.count; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < _products.length
                ? _buildCard(_products[i])
                : const SizedBox.shrink(),
          ),
        ],
      ],
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
