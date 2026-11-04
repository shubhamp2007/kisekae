import 'package:flutter/material.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/wishlist.dart';
import 'package:kisekae/screens/product_screen.dart';
import 'package:kisekae/services/wishlist_service.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();

  List<WishlistItem> _wishlistItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  String _errorText(Object e) {
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _fetchWishlist({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await _wishlistService.getWishlistItems();

      if (!mounted) return;

      setState(() {
        _wishlistItems = items;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (showSpinner || _wishlistItems.isEmpty) {
          _errorMessage = _errorText(e);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _openProduct(WishlistItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: item.product.id),
      ),
    );
    if (mounted) _fetchWishlist(showSpinner: false);
  }

  Future<void> _moveAllToCart() async {
    final inStockItems = _wishlistItems
        .where((item) => item.product.isInStock)
        .toList();

    if (inStockItems.isEmpty) {
      _showSnack('No in-stock items available to move to cart.');
      return;
    }

    final productIds = inStockItems.map((item) => item.product.id).toList();

    try {
      final result = await _wishlistService.bulkMoveToCart(productIds);

      if (!mounted) return;

      setState(() {
        _wishlistItems.removeWhere(
          (item) => productIds.contains(item.product.id),
        );
      });

      final moved = result.movedCount > 0
          ? result.movedCount
          : productIds.length - result.skippedCount;

      _showSnack(
        '$moved item(s) moved to cart.${result.skippedCount > 0 ? ' ${result.skippedCount} skipped.' : ''}',
        color: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorText(e), color: Colors.red);
      _fetchWishlist(showSpinner: false);
    }
  }

  Future<void> _moveToCart(WishlistItem item) async {
    final index = _wishlistItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      _wishlistItems.removeAt(index);
    });

    try {
      final result = await _wishlistService.moveToCart(item.product.id);

      if (!mounted) return;

      _showSnack(result.message, color: Colors.green);
    } catch (e) {
      if (!mounted) return;

      final notFound = e is ApiException && e.code == 'WISHLIST_ITEM_NOT_FOUND';
      if (e is ApiException && !notFound) {
        setState(() => _wishlistItems.insert(index, item));
      } else {
        _fetchWishlist(showSpinner: false);
      }

      _showSnack(_errorText(e), color: Colors.red);
    }
  }

  Future<void> _removeWishlistItem(WishlistItem item) async {
    final index = _wishlistItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      _wishlistItems.removeAt(index);
    });

    try {
      final message = await _wishlistService.removeWishlistItem(
        item.product.id,
      );

      if (!mounted) return;

      _showSnack(message);
    } catch (e) {
      if (!mounted) return;

      final notFound = e is ApiException && e.code == 'WISHLIST_ITEM_NOT_FOUND';
      if (e is ApiException && !notFound) {
        setState(() => _wishlistItems.insert(index, item));
      } else {
        _fetchWishlist(showSpinner: false);
      }

      _showSnack(_errorText(e), color: Colors.red);
    }
  }

  Future<void> _showClearWishlistConfirmationDialog() async {
    bool isClearing = false;

    await showDialog(
      context: context,
      barrierDismissible: !isClearing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFF9F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFB78876)),
              ),
              title: const Text(
                "Clear Wishlist",
                style: TextStyle(
                  color: Color(0xFF8B2E3E),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                "Are you sure you want to clear your wishlist?",
                style: TextStyle(color: Colors.black87, fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: isClearing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ),
                ElevatedButton(
                  onPressed: isClearing
                      ? null
                      : () async {
                          setDialogState(() => isClearing = true);

                          try {
                            final message = await _wishlistService
                                .clearWishlist();

                            if (!mounted) return;
                            Navigator.pop(dialogContext);

                            setState(() {
                              _wishlistItems.clear();
                            });

                            _showSnack(message, color: Colors.green);
                          } catch (e) {
                            setDialogState(() => isClearing = false);
                            _showSnack(_errorText(e), color: Colors.red);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  child: isClearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Clear",
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBgColor = Color(0xFFEFECE6);
    const primaryBurgundy = Color(0xFF8B2E3E);

    final hasInStockItems = _wishlistItems.any(
      (item) => item.product.isInStock,
    );

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: pageBgColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Wishlist",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (_wishlistItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryBurgundy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_wishlistItems.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_wishlistItems.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              color: const Color(0xFFFFF9F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'move_all') {
                  _moveAllToCart();
                } else if (value == 'clear_all') {
                  _showClearWishlistConfirmationDialog();
                }
              },
              itemBuilder: (context) => [
                if (hasInStockItems)
                  const PopupMenuItem(
                    value: 'move_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                          color: primaryBurgundy,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Move All to Cart",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryBurgundy,
                          ),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "Clear Wishlist",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B2E3E)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.black54),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchWishlist,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B2E3E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text("Retry", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_wishlistItems.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF8B2E3E),
        onRefresh: () => _fetchWishlist(showSpinner: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Your wishlist is empty",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Save items you like to review or purchase later",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF8B2E3E),
      onRefresh: () => _fetchWishlist(showSpinner: false),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _wishlistItems.length,
        itemBuilder: (context, index) {
          final item = _wishlistItems[index];
          return _buildWishlistCard(item);
        },
      ),
    );
  }

  Widget _buildWishlistCard(WishlistItem item) {
    const primaryBurgundy = Color(0xFF8B2E3E);
    const cardBgColor = Color(0xFFFFF9F2);
    final product = item.product;

    return GestureDetector(
      onTap: () => _openProduct(item),
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DDD3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeWishlistItem(item),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!product.isInStock)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "OUT OF STOCK",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.store != null)
                          Text(
                            product.store!.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "₹${product.price}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryBurgundy,
                              ),
                            ),
                            if (product.compareAtPrice != null &&
                                product.compareAtPrice!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                "₹${product.compareAtPrice}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black38,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: product.isInStock
                            ? () => _moveToCart(item)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBurgundy,
                          side: BorderSide(
                            color: product.isInStock
                                ? primaryBurgundy
                                : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          product.isInStock ? "MOVE TO CART" : "OUT OF STOCK",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: product.isInStock
                                ? primaryBurgundy
                                : Colors.grey,
                          ),
                        ),
                      ),
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

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFECE4E4),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.black26,
          size: 32,
        ),
      ),
    );
  }
}
