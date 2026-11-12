import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/advertising.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/services/advertising.dart';
import 'package:kisekae/services/format.dart';

class PromoteProductsScreen extends StatefulWidget {
  final int storeId;
  final Future<List<PromotableProduct>> Function() loadProducts;

  const PromoteProductsScreen({
    super.key,
    required this.storeId,
    required this.loadProducts,
  });

  @override
  State<PromoteProductsScreen> createState() => _PromoteProductsScreenState();
}

class _PromoteProductsScreenState extends State<PromoteProductsScreen> {
  final _ops = AdvertisingOperations();
  List<PromotableProduct> _products = [];
  Set<int> _already = {};
  final Set<int> _selected = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait<dynamic>([
        widget.loadProducts(),
        _ops.getPromotedProducts(widget.storeId),
      ]);
      if (!mounted) return;
      setState(() {
        _products = r[0] as List<PromotableProduct>;
        _already = (r[1] as List<PromotedProduct>)
            .map((p) => p.productId)
            .toSet();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your products');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _selected.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _ops.promoteProducts(widget.storeId, _selected.toList());
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Something went wrong. Please try again');
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
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
          onPressed: _submitting ? null : () => Navigator.pop(context),
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
          'Promote products',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body(cs)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_selected.isEmpty || _submitting)
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          _selected.isEmpty
                              ? 'Select products'
                              : 'Promote ${_selected.length} '
                                    '${_selected.length == 1 ? 'product' : 'products'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Add products to your store first, then promote them here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _products[i];
        final promoted = _already.contains(p.id);
        final selected = _selected.contains(p.id);

        return Material(
          color: context.appColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? cs.primary : context.appColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: promoted
                ? null
                : () => setState(
                    () =>
                        selected ? _selected.remove(p.id) : _selected.add(p.id),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.checkroom, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          inr(p.price),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (promoted)
                    Text(
                      'Promoted',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    )
                  else
                    Checkbox(
                      value: selected,
                      activeColor: cs.primary,
                      checkColor: cs.onPrimary,
                      onChanged: (_) => setState(
                        () => selected
                            ? _selected.remove(p.id)
                            : _selected.add(p.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
