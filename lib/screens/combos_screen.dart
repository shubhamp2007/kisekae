import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/tryon_combo_model.dart';
import 'package:kisekae/screens/product_screen.dart';
import 'package:kisekae/services/tryon_service.dart';
import 'package:kisekae/widgets/combo_helper.dart';

class CombosScreen extends StatefulWidget {
  const CombosScreen({super.key});

  @override
  State<CombosScreen> createState() => _CombosScreenState();
}

class _CombosScreenState extends State<CombosScreen> {
  final TryOnService _service = TryOnService();
  final CancelToken _cancelToken = CancelToken();

  List<TryOnCombo> _combos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken.cancel('CombosScreen disposed');
    super.dispose();
  }

  String _msg(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final combos = await _service.getUserCombos(cancelToken: _cancelToken);
      if (!mounted) return;
      setState(() {
        _combos = combos;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() {
        _loading = false;
        _error = _msg(e, 'Could not load your combos');
      });
    }
  }

  Future<void> _confirmDelete(TryOnCombo combo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appColors.card,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete combo?', style: TextStyle(color: ctx.cs.onSurface)),
        content: Text(
          '"${combo.name}" will be removed. This can\'t be undone.',
          style: TextStyle(color: ctx.cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: ctx.appColors.mutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: ctx.cs.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteCombo(comboId: combo.id, cancelToken: _cancelToken);
      if (!mounted) return;
      setState(() => _combos.removeWhere((c) => c.id == combo.id));
      messenger.showSnackBar(const SnackBar(content: Text('Combo deleted')));
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_msg(e, 'Could not delete combo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: cs.onSurface,
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
        title: Text(
          'My Combos',
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final cs = context.cs;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null && _combos.isEmpty) {
      return _Message(
        icon: Icons.error_outline,
        title: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_combos.isEmpty) {
      return const _Message(
        icon: Icons.checkroom_outlined,
        title: 'No combos yet',
        subtitle: 'Open any product and tap "Add to combo" to start putting outfits together.',
      );
    }

    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: context.appColors.card,
      onRefresh: () => _load(showSpinner: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _combos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ComboCard(
          combo: _combos[i],
          onDelete: () => _confirmDelete(_combos[i]),
        ),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final TryOnCombo combo;
  final VoidCallback onDelete;

  const _ComboCard({required this.combo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;
    final items = combo.itemViews;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(fontSize: 12, color: c.mutedText),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete combo',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: cs.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'This combo is empty',
              style: TextStyle(fontSize: 13, color: c.mutedText),
            )
          else
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _ItemThumb(
                  item: items[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailsScreen(productId: items[i].productId),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  final ComboItemView item;
  final VoidCallback onTap;

  const _ItemThumb({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;
    final url = item.imageUrl;

    final placeholder = Icon(
      Icons.image_not_supported_outlined,
      color: c.mutedText,
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 72,
          height: 84,
          color: cs.surfaceContainerHighest,
          child: (url == null || url.isEmpty)
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.primary.withAlpha(153)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.mutedText),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
