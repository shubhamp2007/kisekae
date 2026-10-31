import 'package:flutter/material.dart';
import 'package:kisekae/models/cart.dart';
import 'package:kisekae/screens/checkout.dart';
import 'package:kisekae/services/cart_service.dart';
import 'package:kisekae/services/wishlist_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final WishlistService _wishlistService = WishlistService();

  CartModel? _cartModel;
  bool _isLoading = true;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    setState(() => _isLoading = true);
    try {
      final cart = await _cartService.getCart();
      if (mounted) {
        setState(() {
          _cartModel = cart;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cart: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _confirmClearCart() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      _clearCart();
    }
  }

  Future<void> _clearCart() async {
    setState(() => _isProcessingAction = true);
    try {
      final updatedCart = await _cartService.clearCart();
      if (mounted) {
        setState(() {
          _cartModel = updatedCart;
          _isProcessingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cart: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateQuantity(int itemId, int currentQty, int delta) async {
    final newQty = currentQty + delta;
    if (newQty < 1) return;

    setState(() => _isProcessingAction = true);
    try {
      final updatedCart = await _cartService.updateItemQuantity(
        itemId: itemId,
        quantity: newQty,
      );
      if (mounted) {
        setState(() {
          _cartModel = updatedCart;
          _isProcessingAction = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeItem(int itemId) async {
    setState(() => _isProcessingAction = true);
    try {
      final updatedCart = await _cartService.removeCartItem(itemId: itemId);
      if (mounted) {
        setState(() {
          _cartModel = updatedCart;
          _isProcessingAction = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item removed from cart')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove item: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _moveToWishlist(CartItem item) async {
    setState(() => _isProcessingAction = true);
    try {
      await _wishlistService.addToWishlist(productId: item.product.id);
      final updatedCart = await _cartService.removeCartItem(itemId: item.id);
      if (mounted) {
        setState(() {
          _cartModel = updatedCart;
          _isProcessingAction = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Moved item to Wishlist')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move to wishlist: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleCheckout() async {
    if (_cartModel == null || _cartModel!.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    setState(() => _isProcessingAction = true);
    try {
      final validation = await _cartService.validateCart();
      setState(() => _isProcessingAction = false);

      if (!validation.isValid) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cart Validation Issues'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: validation.issues
                    .map((issue) => Text('• $issue'))
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CheckoutScreen(cart: _cartModel!)),
        );
        if (mounted) _fetchCart();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation error: ${e.toString()}')),
        );
      }
    }
  }

  double get _mrpTotal {
    if (_cartModel == null) return 0;
    double total = 0;
    for (var item in _cartModel!.items) {
      final comparePrice =
          double.tryParse(item.product.compareAtPrice ?? '') ??
          double.tryParse(item.product.price) ??
          0;
      total += comparePrice * item.quantity;
    }
    return total;
  }

  double get _subtotal {
    return double.tryParse(_cartModel?.subtotal ?? '0') ?? 0;
  }

  double get _discountTotal {
    final diff = _mrpTotal - _subtotal;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "My Cart",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_cartModel != null && _cartModel!.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _isProcessingAction ? null : _confirmClearCart,
                child: const Text(
                  "Clear All",
                  style: TextStyle(
                    color: Color(0xFF8B2E3E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B2E3E)),
            )
          : RefreshIndicator(
              onRefresh: _fetchCart,
              color: const Color(0xFF8B2E3E),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: _cartModel == null || _cartModel!.items.isEmpty
                          ? const Center(
                              child: Text(
                                "Your cart is empty",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _cartModel!.items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final item = _cartModel!.items[index];
                                return productCard(item);
                              },
                            ),
                    ),
                    if (_cartModel != null && _cartModel!.items.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Price details",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFFE0E0E0),
                        ),
                        child: Column(
                          children: [
                            priceRow("MRP", _mrpTotal.toInt()),
                            priceRow("Discounts", _discountTotal.toInt()),
                            priceRow("Total amount", _subtotal.toInt()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.place_rounded),
                          SizedBox(width: 4),
                          Text("Address-Home (saved address)"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isProcessingAction
                              ? null
                              : _handleCheckout,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B2E3E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isProcessingAction
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Buy Now",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget productCard(CartItem item) {
    final imagePath =
        item.product.imageUrl ??
        item.product.thumbnail ??
        "assets/images/clothes/4.jpg";

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 120,
                width: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF8B2E3E), width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath.startsWith('http')
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => Image.asset(
                          "assets/images/clothes/4.jpg",
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Size - ${item.size.isEmpty ? "M" : item.size}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      '₹${item.product.price}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEE9E4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: _isProcessingAction
                                ? null
                                : () => _updateQuantity(
                                    item.id,
                                    item.quantity,
                                    -1,
                                  ),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontSize: 20),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: _isProcessingAction
                                ? null
                                : () => _updateQuantity(
                                    item.id,
                                    item.quantity,
                                    1,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _moveToWishlist(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B2E3E),
                    padding: const EdgeInsets.all(8),
                    side: const BorderSide(color: Color(0xFF8B2E3E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text("Wishlist", style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _removeItem(item.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B2E3E),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Color(0xFF8B2E3E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text("Remove", style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget priceRow(String label, int price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 40),
          Text('₹$price', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
