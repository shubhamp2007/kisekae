import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/seller_product.dart';
import 'package:kisekae/screens/sellerproductdetail.dart';
import 'package:kisekae/services/seller_product.dart';

class InventoryScreen extends StatefulWidget {
  final int storeId;

  const InventoryScreen({super.key, required this.storeId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _lowStockLimit = 50;

  final HandleProduct _productService = HandleProduct();

  bool _isLoading = true;
  List<Product> _allProducts = [];
  String _selectedFilter = 'Current Stock';

  final List<String> _filters = ['Current Stock', 'Low Stock', 'Out of Stock'];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);

    try {
      final products = await _productService.getStoreProducts(
        storeId: widget.storeId,
        status: 'ACTIVE',
      );

      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is ApiException
          ? e.message
          : 'Failed to load inventory';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<Product> _visibleProducts() {
    switch (_selectedFilter) {
      case 'Low Stock':
        return _allProducts
            .where((p) => p.totalStock > 0 && p.totalStock < _lowStockLimit)
            .toList();
      case 'Out of Stock':
        return _allProducts.where((p) => p.totalStock <= 0).toList();
      default:
        return _allProducts.where((p) => p.totalStock > 0).toList();
    }
  }

  Map<String, dynamic> _getStatusDisplay(Product product) {
    final colors = Theme.of(context).colorScheme;
    if (product.totalStock <= 0) {
      return {'text': 'Out of stock', 'color': colors.error};
    } else if (product.totalStock < _lowStockLimit) {
      return {'text': 'Low stock', 'color': context.appColors.warning};
    } else {
      return {'text': 'In stock', 'color': context.appColors.success};
    }
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductDetailScreen(
          storeId: widget.storeId,
          productId: product.id,
        ),
      ),
    ).then((_) {
      if (mounted) _fetchProducts(showLoader: false);
    });
  }

  Widget _productCard(Product product) {
    final colors = Theme.of(context).colorScheme;
    final cardBackgroundColor = context.appColors.card;
    final statusDisplay = _getStatusDisplay(product);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(product),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: colors.outlineVariant,
                        child: Icon(
                          Icons.image_not_supported,
                          color: colors.outline,
                        ),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: colors.outlineVariant,
                      child: Icon(Icons.checkroom, color: colors.outline),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product.sku?.trim().isNotEmpty ?? false)
                        ? "Product no. - ${product.sku}"
                        : "Product no. - ${product.id}",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Stock - ${product.totalStock}",
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "Status - ",
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        statusDisplay['text'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusDisplay['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = colors.surface;
    final primaryColor = colors.primary;

    final products = _visibleProducts();

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
          "Inventory",
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedFilter != filter) {
                          setState(() => _selectedFilter = filter);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : products.isEmpty
                ? Center(
                    child: Text(
                      "No products found",
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: () => _fetchProducts(showLoader: false),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _productCard(products[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
