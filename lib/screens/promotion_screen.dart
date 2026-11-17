import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/advertising.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/seasonal_sale_seller.dart';
import 'package:kisekae/screens/promotional_detail_screen.dart';
import 'package:kisekae/services/seasonal_sale_seller_service.dart';

class PromotionsScreen extends StatefulWidget {
  final int storeId;

  final Future<List<PromotableProduct>> Function() loadStoreProducts;

  const PromotionsScreen({
    super.key,
    required this.storeId,
    required this.loadStoreProducts,
  });

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  static const _tabs = <(String, String)>[
    ('Active', 'active'),
    ('Scheduled', 'upcoming'),
    ('Past', 'past'),
  ];

  final _ops = SeasonalSales();

  int _tab = 0;
  List<SeasonalSale> _sales = [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    final id = ++_requestId; // ignore stale responses when tabs change fast
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sales = await _ops.getSales(widget.storeId, status: _tabs[_tab].$2);
      if (!mounted || id != _requestId) return;
      setState(() {
        _sales = sales;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = 'Could not load promotions');
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    setState(() {
      _tab = index;
      _sales = [];
    });
    _load();
  }

  Future<void> _openSale(SeasonalSale sale) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromotionDetailScreen(
          storeId: widget.storeId,
          saleId: sale.id,
          loadStoreProducts: widget.loadStoreProducts,
        ),
      ),
    );
    if (mounted) _load(spinner: false);
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
          onPressed: () => Navigator.pop(context),
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
          'Promotions',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: _tabChip(cs, i)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: cs.primary,
                onRefresh: () => _load(spinner: false),
                child: _body(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(ColorScheme cs, int index) {
    final selected = index == _tab;
    return Material(
      color: selected ? cs.primary : context.appColors.card,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _selectTab(index),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              _tabs[index].$1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null) {
      return _centered([
        Text(
          _error!,
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
      ]);
    }

    if (_sales.isEmpty) {
      const messages = [
        'No active promotions right now',
        'No upcoming promotions',
        'No past promotions',
      ];
      return _centered([
        Icon(
          Icons.local_offer_outlined,
          size: 56,
          color: cs.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          messages[_tab],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sales run by Kisekae will show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ]);
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _saleCard(cs, _sales[i]),
    );
  }

  Widget _centered(List<Widget> children) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        ...children,
      ],
    );
  }

  Widget _saleCard(ColorScheme cs, SeasonalSale sale) {
    final subtle = cs.onSurface.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 3),
            blurRadius: 8,
            color: Color(0x1F000000),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sale.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: subtle),
                ),
                if (sale.dateRange.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sale.dateRange,
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  sale.participationText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sale.isParticipating ? cs.primary : subtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _openSale(sale),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Manage',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
