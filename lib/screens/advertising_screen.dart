import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/advertising.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/screens/promote_product.dart';

import 'package:kisekae/services/advertising.dart';
import 'package:kisekae/services/format.dart';

class AdvertisementScreen extends StatefulWidget {
  final int storeId;

  final Future<List<PromotableProduct>> Function() loadStoreProducts;

  const AdvertisementScreen({
    super.key,
    required this.storeId,
    required this.loadStoreProducts,
  });

  @override
  State<AdvertisementScreen> createState() => _AdvertisementScreenState();
}

class _AdvertisementScreenState extends State<AdvertisementScreen> {
  static const _previewCount = 3;

  final _ops = AdvertisingOperations();
  late int _month;
  late int _year;

  AdAnalytics? _data;
  bool _loading = true;
  String? _error;
  bool _showAll = false;
  int? _busyProductId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _load();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month == now.month && _year == now.year;
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: TextStyle(
              color: error
                  ? scheme.onError
                  : (isDark ? Colors.black : Colors.white),
            ),
          ),
          backgroundColor: error ? scheme.error : context.appColors.success,
        ),
      );
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _ops.getAnalytics(
        widget.storeId,
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        setState(() {
          _data = null;
          _error = null;
        });
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your campaigns');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    setState(() {
      _month = m;
      _year = y;
      _showAll = false;
    });
    _load();
  }

  Future<void> _openEditBudget() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BudgetSheet(
        current: (_data?.monthlyBudget ?? 0) > 0 ? _data!.monthlyBudget : null,
        onSave: (amount) => _ops.setBudget(widget.storeId, amount),
      ),
    );
    if (saved != true || !mounted) return;
    _snack('Monthly budget updated');
    _load(spinner: false);
  }

  Future<void> _openPromote() async {
    final promoted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PromoteProductsScreen(
          storeId: widget.storeId,
          loadProducts: widget.loadStoreProducts,
        ),
      ),
    );
    if (promoted == true && mounted) {
      _snack('Products added to promotion');
      _load(spinner: false);
    }
  }

  Future<void> _toggle(PromotedProduct p, bool active) async {
    if (_busyProductId != null) return;
    setState(() => _busyProductId = p.productId);
    try {
      await _ops.setProductActive(widget.storeId, p.productId, active);
      if (!mounted) return;
      await _load(spinner: false);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _remove(PromotedProduct p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from promotion?'),
        content: Text('${p.name} will stop being advertised.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busyProductId != null) return;

    setState(() => _busyProductId = p.productId);
    try {
      await _ops.removeProduct(widget.storeId, p.productId);
      if (!mounted) return;
      _snack('Removed from promotion');
      await _load(spinner: false);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
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
          'Advertisement',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () => _load(spinner: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _banner(cs),
              _monthSwitcher(cs),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _errorBox(cs)
              else ...[
                _overview(cs),
                const SizedBox(height: 24),
                _campaignsHeader(cs),
                const SizedBox(height: 12),
                _campaigns(cs),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 3),
            blurRadius: 8,
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grow your brand\nwith kisekae Ads',
            style: TextStyle(fontSize: 20, height: 1.25, color: cs.onPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Reach more buyers. Get better visibility',
            style: TextStyle(
              fontSize: 12,
              color: cs.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _openPromote,
              style: FilledButton.styleFrom(
                backgroundColor: cs.onPrimary,
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Create Ad Campaign',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthSwitcher(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _loading ? null : () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
            color: cs.primary,
          ),
          Text(
            '${monthName(_month)} $_year',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            onPressed: (_loading || _isCurrentMonth)
                ? null
                : () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
            color: cs.primary,
          ),
        ],
      ),
    );
  }

  Widget _overview(ColorScheme cs) {
    final d = _data;
    final budget = d?.monthlyBudget ?? 0;
    final spent = d?.currentSpend ?? 0;
    final used = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);

    return _card(
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
                      'Monthly budget',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      budget > 0 ? inr(budget) : 'Not set',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: budget > 0
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openEditBudget,
                icon: Icon(
                  budget > 0 ? Icons.edit_outlined : Icons.add,
                  size: 18,
                ),
                label: Text(budget > 0 ? 'Edit' : 'Set budget'),
                style: TextButton.styleFrom(foregroundColor: cs.primary),
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: used,
                minHeight: 6,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${inr(spent)} spent',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${inr(d?.remainingBudget ?? (budget - spent))} left',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (d != null) ...[
            const Divider(height: 28),
            Row(
              children: [
                _stat(cs, 'Clicks', '${d.totalClicks}'),
                _stat(cs, 'Orders', '${d.totalOrders}'),
                _stat(
                  cs,
                  'Conversion',
                  '${d.conversionRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(ColorScheme cs, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campaignsHeader(ColorScheme cs) {
    final count = _data?.products.length ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Campaigns',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        if (count > _previewCount)
          GestureDetector(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll ? 'Show less' : 'View all',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _campaigns(ColorScheme cs) {
    final products = _data?.products ?? const <PromotedProduct>[];

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 52,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No campaigns yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Promote your products to reach more buyers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final visible = _showAll ? products : products.take(_previewCount).toList();
    return Column(
      children: [
        for (final p in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _CampaignCard(
              product: p,
              busy: _busyProductId == p.productId,
              onToggle: (v) => _toggle(p, v),
              onRemove: () => _remove(p),
            ),
          ),
      ],
    );
  }

  Widget _errorBox(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: cs.onSurface),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final PromotedProduct product;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  const _CampaignCard({
    required this.product,
    required this.busy,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = product;
    final statusColor = p.isActive
        ? context.appColors.success
        : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                p.isActive ? 'Running' : 'Paused',
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
              if (busy)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'toggle') onToggle(!p.isActive);
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(p.isActive ? 'Pause' : 'Run'),
                    ),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.checkroom, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inr(p.spend),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p.createdAt != null)
                      Text(
                        'Started ${formatDate(p.createdAt!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      'Clicks - ${p.clicks}  •  Orders - ${p.orders}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  final double? current;
  final Future<AdBudget> Function(double amount) onSave;

  const _BudgetSheet({required this.current, required this.onSave});

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _controller = TextEditingController(
      text: c == null
          ? ''
          : (c == c.roundToDouble()
                ? c.toStringAsFixed(0)
                : c.toStringAsFixed(2)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null) return 'Enter an amount';
    if (amount <= 0) return 'Enter an amount greater than ₹0';
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      await widget.onSave(double.parse(_controller.text.trim()));
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _serverError = 'Something went wrong. Please try again');
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.current == null
                  ? 'Set monthly budget'
                  : 'Edit monthly budget',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              enabled: !_saving,
              autofocus: true,
              validator: _validate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,8}(\.\d{0,2})?'),
                ),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: _border(cs.onSurface),
                enabledBorder: _border(cs.onSurface),
                disabledBorder: _border(cs.onSurface),
                focusedBorder: _border(cs.primary, width: 2),
                errorBorder: _border(cs.error),
                focusedErrorBorder: _border(cs.error, width: 2),
              ),
            ),
            if (_serverError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _serverError!,
                  style: TextStyle(fontSize: 13, color: cs.error),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
