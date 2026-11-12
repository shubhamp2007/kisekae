import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/ar_model.dart';
import 'package:kisekae/services/ar_service.dart';

class TryOnHistoryScreen extends StatefulWidget {
  const TryOnHistoryScreen({super.key});

  @override
  State<TryOnHistoryScreen> createState() => _TryOnHistoryScreenState();
}

class _TryOnHistoryScreenState extends State<TryOnHistoryScreen> {
  final TryOnGenerationService _service = TryOnGenerationService();
  final CancelToken _cancelToken = CancelToken();

  List<TryOnRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken.cancel('TryOnHistoryScreen disposed');
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final items = await _service.getHistory(cancelToken: _cancelToken);
      items.sort((a, b) {
        final da = a.createdAt;
        final db = b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() {
        _loading = false;
        _error = e is ApiException
            ? e.message
            : 'Could not load your try-on history';
      });
    }
  }

  void _open(TryOnRequest item) {
    if (item.isReady && (item.resultImageUrl ?? '').isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TryOnImageViewerScreen(
            url: item.resultImageUrl!,
            title: _titleFor(item),
          ),
        ),
      );
      return;
    }

    final message = item.isFailed
        ? (item.errorMessage ?? 'This try-on could not be completed.')
        : 'This try-on is still being created. Pull down to refresh.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.onSurface,
        title: const Text(
          'Try-On History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_error != null && _items.isEmpty) {
      return _Message(
        icon: Icons.error_outline,
        title: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return const _Message(
        icon: Icons.history,
        title: 'No try-ons yet',
        subtitle: 'Your generated looks will show up here.',
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => _load(showSpinner: false),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) =>
            _HistoryCard(item: _items[i], onTap: () => _open(_items[i])),
      ),
    );
  }
}

String _titleFor(TryOnRequest item) {
  final combo = item.comboName;
  if (combo != null && combo.isNotEmpty) return combo;
  final product = item.productName;
  if (product != null && product.isNotEmpty) return product;
  return 'Try-on';
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final date = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}, ${date.year}';
}

class _HistoryCard extends StatelessWidget {
  final TryOnRequest item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    print(item);
    final url = item.resultImageUrl;
    final hasImage = item.isReady && url != null && url.isNotEmpty;
    final isCombo = (item.comboName ?? '').isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.outlineVariant,
                child: hasImage
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.outline,
                          size: 36,
                        ),
                      )
                    : _StatusPlaceholder(item: item),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCombo) ...[
                        const Icon(Icons.layers_outlined, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _titleFor(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPlaceholder extends StatelessWidget {
  final TryOnRequest item;

  const _StatusPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = item.isFailed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.hourglass_top,
            size: 32,
            color: failed ? colors.error : colors.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            failed ? 'Failed' : 'In progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: failed ? colors.error : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class TryOnDeepLinkScreen extends StatefulWidget {
  final String requestId;

  const TryOnDeepLinkScreen({super.key, required this.requestId});

  @override
  State<TryOnDeepLinkScreen> createState() => _TryOnDeepLinkScreenState();
}

class _TryOnDeepLinkScreenState extends State<TryOnDeepLinkScreen> {
  final TryOnGenerationService _service = TryOnGenerationService();
  final CancelToken _cancelToken = CancelToken();
  bool _loading = true;
  String? _error;
  TryOnRequest? _request;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _cancelToken.cancel('TryOnDeepLinkScreen disposed');
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final req = await _service.getRequest(
        widget.requestId,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _request = req;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() {
        _error = 'Could not load the try-on result.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final req = _request;

    if (req != null && req.isReady && (req.resultImageUrl ?? '').isNotEmpty) {
      return TryOnImageViewerScreen(
        url: req.resultImageUrl!,
        title: _titleFor(req),
      );
    }

    final message = req?.isFailed == true
        ? (req?.errorMessage ?? 'This try-on could not be completed.')
        : _error ?? 'The try-on result is not ready yet.';

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// Full-screen photo viewer: intentionally black in both themes.
class TryOnImageViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const TryOnImageViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<TryOnImageViewerScreen> createState() => _TryOnImageViewerScreenState();
}

class _TryOnImageViewerScreenState extends State<TryOnImageViewerScreen> {
  final CancelToken _cancelToken = CancelToken();
  bool _saving = false;

  @override
  void dispose() {
    _cancelToken.cancel('viewer closed');
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final res = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
      );
      final data = res.data;
      if (data == null || data.isEmpty) throw Exception('empty image');
      await Gal.putImageBytes(Uint8List.fromList(data));
      _snack('Look saved to your gallery');
    } catch (_) {
      _snack('Could not save the look. Please allow photo access and retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Save to gallery',
                  onPressed: _save,
                  icon: const Icon(Icons.download_outlined),
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, __, ___) => const Text(
              'Could not load the image',
              style: TextStyle(color: Colors.white70),
            ),
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
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
