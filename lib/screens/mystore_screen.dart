import 'package:flutter/material.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/seller_product.dart';

import 'package:kisekae/models/store_create.dart';
import 'package:kisekae/screens/editstore_screen.dart';
import 'package:kisekae/screens/seller_gate_screen.dart';
import 'package:kisekae/services/format.dart';
import 'package:kisekae/services/seller_product.dart';
import 'package:kisekae/services/store.dart';

class MyStoreScreen extends StatefulWidget {
  final int storeId;

  const MyStoreScreen({super.key, required this.storeId});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  static const _pageSize = 20;

  final _storeOperations = StoreOperations();
  final _productOperations = HandleProduct();

  Store? _store;
  bool _loading = true;
  bool _archiving = false;
  String? _error;

  final List<Product> _products = [];
  int _productPage = 1;
  bool _productsLoading = true;
  bool _loadingMoreProducts = false;
  bool _hasMoreProducts = false;
  String? _productsError;

  bool get _isOwner => _store?.myRole.toUpperCase() == 'OWNER';

  @override
  void initState() {
    super.initState();
    _load();
    _loadProducts();
  }

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final store = await _storeOperations.getStore(widget.storeId);
      if (!mounted) return;
      setState(() {
        _store = store;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load your store');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _productsLoading = true;
        _productsError = null;
      });
    }
    try {
      final items = await _productOperations.getStoreProducts(
        storeId: widget.storeId,
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _productPage = 1;
        _hasMoreProducts = items.length >= _pageSize;
        _productsError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _productsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _productsError = 'Could not load products');
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingMoreProducts || !_hasMoreProducts) return;
    setState(() => _loadingMoreProducts = true);
    try {
      final next = _productPage + 1;
      final items = await _productOperations.getStoreProducts(
        storeId: widget.storeId,
        page: next,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        final seen = _products.map((p) => p.id).toSet();
        _products.addAll(items.where((p) => seen.add(p.id)));
        _productPage = next;
        _hasMoreProducts = items.length >= _pageSize;
      });
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } catch (_) {
      if (mounted) _showMessage('Could not load more products', error: true);
    } finally {
      if (mounted) setState(() => _loadingMoreProducts = false);
    }
  }

  Future<void> _edit() async {
    final store = _store;
    if (store == null) return;
    final updated = await Navigator.push<Store>(
      context,
      MaterialPageRoute(builder: (_) => EditStoreScreen(store: store)),
    );
    if (updated != null && mounted) {
      setState(() => _store = updated);
    }
  }

  Future<void> _archive() async {
    final store = _store;
    if (store == null || _archiving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive store?'),
        content: Text(
          '${store.name} will be archived and pending invitations will be revoked. This can\'t be undone from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _archiving = true);
    try {
      await _storeOperations.archiveStore(store.id);
      if (!mounted) return;
      _showMessage('${store.name} was archived');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellerGateScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Widget _productsSection(ColorScheme cs) {
    final title = Text(
      'Products',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
    );

    Widget content;
    if (_productsLoading) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    } else if (_productsError != null && _products.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              _productsError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadProducts,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_products.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No products added yet.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final itemWidth = (c.maxWidth - gap) / 2;
              final imageHeight = itemWidth * 1.05;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: 14,
                  mainAxisExtent: imageHeight + 72,
                ),
                itemBuilder: (_, i) => _StoreProductCard(
                  product: _products[i],
                  imageHeight: imageHeight,
                ),
              );
            },
          ),
          if (_hasMoreProducts)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _loadingMoreProducts ? null : _loadMoreProducts,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loadingMoreProducts
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : const Text('View more'),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 12), content],
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    final store = _store;
    if (store == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Text(
            _error ?? 'Failed to load your store',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StoreHeader(store: store),
        const SizedBox(height: 20),
        Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          store.description.trim().isEmpty
              ? 'No description added yet.'
              : store.description,
          style: TextStyle(fontSize: 13, height: 1.35, color: cs.onSurface),
        ),
        const SizedBox(height: 20),
        _productsSection(cs),
        _ContactSection(store: store),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        leading: IconButton(
          onPressed: _archiving ? null : () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
        title: Text(
          'My Store',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        actions: [
          if (_store != null)
            _archiving
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: cs.primary),
                    onSelected: (value) {
                      if (value == 'edit') _edit();
                      if (value == 'archive') _archive();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit store'),
                      ),
                      if (_isOwner)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            'Archive store',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () => Future.wait([
            _load(showSpinner: false),
            _loadProducts(spinner: false),
          ]),
          child: _body(cs),
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final Store store;

  const _StoreHeader({required this.store});

  Widget _bannerPlaceholder(ColorScheme cs) {
    return Container(
      color: const Color(0xFFE4D6D0),
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_outlined,
        size: 40,
        color: cs.primary.withValues(alpha: 0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bannerUrl = store.bannerUrl;
    final logoUrl = store.logoUrl;
    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    final initial = store.name.trim().isEmpty
        ? 'S'
        : store.name.trim()[0].toUpperCase();

    final Widget logoFallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasBanner
                    ? Image.network(
                        bannerUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerPlaceholder(cs),
                      )
                    : _bannerPlaceholder(cs),
              ),
            ),
            Positioned(
              left: 12,
              bottom: -28,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6D6A6A),
                  border: Border.all(color: cs.surface, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => logoFallback,
                      )
                    : logoFallback,
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              store.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            _Chip(
              label: store.isBusinessVerified
                  ? 'Verified'
                  : 'Pending verification',
              background: store.isBusinessVerified
                  ? const Color(0xFFCFE8D1)
                  : const Color(0xFFFBEFD5),
              foreground: store.isBusinessVerified
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFB7791F),
            ),
            if (store.status == 'INACTIVE')
              const _Chip(
                label: 'Inactive',
                background: Color(0xFFECECEC),
                foreground: Color(0xFF616161),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final Store store;

  const _ContactSection({required this.store});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final rows = <(IconData, String)>[
      if ((store.websiteLink ?? '').isNotEmpty)
        (Icons.language, store.websiteLink!),
      if ((store.instagramLink ?? '').isNotEmpty)
        (Icons.camera_alt_outlined, store.instagramLink!),
      if (store.contactEmail.isNotEmpty)
        (Icons.mail_outline, store.contactEmail),
      if (store.contactPhone.isNotEmpty)
        (Icons.phone_outlined, store.contactPhone),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & links',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(row.$1, size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  final Product product;
  final double imageHeight;

  const _StoreProductCard({required this.product, required this.imageHeight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = product;

    final url = (p.thumbnail?.isNotEmpty ?? false)
        ? p.thumbnail
        : ((p.imageUrl?.isNotEmpty ?? false) ? p.imageUrl : null);
    final rating = p.averageRating ?? 0.0;
    final hasRating = rating > 0;

    final placeholder = Container(
      color: const Color(0xFFE4D6D0),
      alignment: Alignment.center,
      child: Icon(
        Icons.checkroom,
        size: 36,
        color: cs.primary.withValues(alpha: 0.6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: url == null
                ? placeholder
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => placeholder,
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                p.storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.star,
              size: 13,
              color: hasRating
                  ? Colors.amber
                  : cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          inr(double.tryParse(p.price) ?? 0),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
