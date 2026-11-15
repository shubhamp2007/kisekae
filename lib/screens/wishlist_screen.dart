import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
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

    // Pick a readable text color for whatever background we were given.
    TextStyle? textStyle;
    if (color != null) {
      final onColor =
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black;
      textStyle = TextStyle(color: onColor);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: textStyle),
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
        color: context.appColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorText(e), color: context.cs.error);
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

      _showSnack(result.message, color: context.appColors.success);
    } catch (e) {
      if (!mounted) return;

      final notFound = e is ApiException && e.code == 'WISHLIST_ITEM_NOT_FOUND';
      if (e is ApiException && !notFound) {
        setState(() => _wishlistItems.insert(index, item));
      } else {
        _fetchWishlist(showSpinner: false);
      }

      _showSnack(_errorText(e), color: context.cs.error);
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

      _showSnack(_errorText(e), color: context.cs.error);
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
            final cs = context.cs;
            final c = context.appColors;

            return AlertDialog(
              backgroundColor: c.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cs.outline),
              ),
              title: Text(
                "Clear Wishlist",
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Text(
                "Are you sure you want to clear your wishlist?",
                style: TextStyle(color: cs.onSurface, fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: isClearing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: c.mutedText, fontSize: 15),
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

                            _showSnack(message, color: c.success);
                          } catch (e) {
                            setDialogState(() => isClearing = false);
                            _showSnack(_errorText(e), color: cs.error);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
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
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onError,
                          ),
                        )
                      : Text(
                          "Clear",
                          style: TextStyle(color: cs.onError, fontSize: 15),
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
    final cs = context.cs;
    final c = context.appColors;

    final hasInStockItems = _wishlistItems.any(
      (item) => item.product.isInStock,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: cs.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Wishlist",
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (_wishlistItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_wishlistItems.length}",
                  style: TextStyle(
                    color: cs.onPrimary,
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
              icon: Icon(Icons.more_vert, color: cs.onSurface),
              color: c.card,
              surfaceTintColor: Colors.transparent,
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
                  PopupMenuItem(
                    value: 'move_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Move All to Cart",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: cs.error),
                      const SizedBox(width: 8),
                      Text(
                        "Clear Wishlist",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
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
    final cs = context.cs;
    final c = context.appColors;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.mutedText),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: cs.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchWishlist,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text("Retry", style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        ),
      );
    }

    if (_wishlistItems.isEmpty) {
      return RefreshIndicator(
        color: cs.primary,
        backgroundColor: c.card,
        onRefresh: () => _fetchWishlist(showSpinner: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: c.mutedText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Your wishlist is empty",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Save items you like to review or purchase later",
                    style: TextStyle(fontSize: 13, color: c.mutedText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: c.card,
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
    final cs = context.cs;
    final c = context.appColors;
    final product = item.product;

    return GestureDetector(
      onTap: () => _openProduct(item),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border, width: 1),
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
                // Remove button: a scrim over a photo, so it keeps a dark
                // translucent circle + white icon in both themes for contrast.
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeWishlistItem(item),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cs.scrim.withValues(alpha: 0.4),
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
                        color: cs.onSurface.withValues(alpha: 0.87),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "OUT OF STOCK",
                        style: TextStyle(
                          color: cs.surface,
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
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: c.mutedText,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            if (product.compareAtPrice != null &&
                                product.compareAtPrice!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                "₹${product.compareAtPrice}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.mutedText,
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
                          foregroundColor: cs.primary,
                          side: BorderSide(
                            color: product.isInStock ? cs.primary : cs.outline,
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
                            color: product.isInStock ? cs.primary : c.mutedText,
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
      color: context.cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: context.appColors.mutedText,
          size: 32,
        ),
      ),
    );
  }
}
