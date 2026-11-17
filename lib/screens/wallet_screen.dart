import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/model.dart';
import 'package:kisekae/services/storage.dart';
import 'package:kisekae/services/wallet_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';

const _months = [
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

String _inr(double value, {bool decimals = true}) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  final fraction = (!decimals && parts[1] == '00') ? '' : '.${parts[1]}';
  return '₹$whole$fraction';
}

String _formatDateTime(DateTime date) {
  final d = date.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hour:$minute $suffix';
}

class _PendingVerify {
  final String paymentId;
  final String orderId;
  final String signature;
  final double amount;

  const _PendingVerify({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.amount,
  });
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _ops = WalletOperations();
  final _razorpay = Razorpay();
  final _scroll = ScrollController();

  Wallet? _wallet;
  final List<WalletTransaction> _txns = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool _paying = false;
  TopUpOrder? _order;
  double? _orderAmount;
  _PendingVerify? _pending;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _scroll.dispose();
    super.dispose();
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
      final r = await Future.wait<dynamic>([
        _ops.getWallet(),
        _ops.getTransactions(page: 1),
      ]);
      if (!mounted) return;
      final wallet = r[0] as Wallet;
      final page = r[1] as TransactionPage;
      setState(() {
        _wallet = wallet;
        _txns
          ..clear()
          ..addAll(page.results);
        _page = 1;
        _hasMore = page.hasNext;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (_wallet != null) _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your wallet');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _ops.getTransactions(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _txns.addAll(page.results);
        _page += 1;
        _hasMore = page.hasNext;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openAddMoney() async {
    final wallet = _wallet;
    if (wallet == null || _paying || _verifying) return;
    if (wallet.remainingLimit < 1) {
      _snack('Your wallet is full', error: true);
      return;
    }

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddMoneySheet(
        remaining: wallet.remainingLimit,
        limit: wallet.balanceLimit,
      ),
    );
    if (amount == null || !mounted) return;
    await _startTopUp(amount);
  }

  Future<void> _startTopUp(double amount) async {
    setState(() => _paying = true);
    try {
      final order = await _ops.createTopUpOrder(amount);
      _order = order;
      _orderAmount = amount;
      final email = await TokenStorage().readEmail();

      _razorpay.open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountInPaise,
        'currency': order.currency,
        'name': 'Kisekae',
        'description': 'Wallet top-up',
        'prefill': {if (email != null && email.isNotEmpty) 'email': email},
        'theme': {'color': '#8B2E3E'},
      });
    } on ApiException catch (e) {
      _snack(e.message, error: true);
      if (mounted) setState(() => _paying = false);
    } catch (_) {
      _snack('Could not start the payment. Please try again', error: true);
      if (mounted) setState(() => _paying = false);
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    final order = _order;
    final amount = _orderAmount;
    if (order == null || amount == null) return;
    _verify(
      _PendingVerify(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? order.orderId,
        signature: response.signature ?? '',
        amount: amount,
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _paying = false);
    _snack(
      response.code == Razorpay.PAYMENT_CANCELLED
          ? 'Payment cancelled'
          : 'Payment failed. Please try again',
      error: true,
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  Future<void> _verify(_PendingVerify p) async {
    if (!mounted) return;
    setState(() {
      _paying = false;
      _verifying = true;
      _pending = null;
    });
    try {
      final wallet = await _ops.verifyTopUp(
        paymentId: p.paymentId,
        orderId: p.orderId,
        signature: p.signature,
        amount: p.amount,
      );
      if (!mounted) return;

      var txns = wallet.recentTransactions;
      var hasMore = false;
      try {
        final page = await _ops.getTransactions(page: 1);
        txns = page.results;
        hasMore = page.hasNext;
      } catch (_) {}
      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _txns
          ..clear()
          ..addAll(txns);
        _page = 1;
        _hasMore = hasMore;
      });
      _snack('${_inr(p.amount)} added to your wallet');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _pending = p);
      _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = p);
      _snack('Could not confirm your payment yet', error: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
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
          'Wallet',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () => _load(spinner: false),
          child: _body(cs),
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading && _wallet == null) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_wallet == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Text(
            _error ?? 'Could not load your wallet',
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
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_pending != null) _pendingBanner(cs, _pending!),
        _balanceCard(cs, _wallet!),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'You can keep up to ${_inr(_wallet!.balanceLimit, decimals: false)} in your wallet',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Transactions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (_txns.isEmpty)
          _emptyState(cs)
        else
          for (final txn in _txns) _TransactionTile(txn: txn),
        if (_loadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _balanceCard(ColorScheme cs, Wallet wallet) {
    final used = wallet.balanceLimit <= 0
        ? 0.0
        : (wallet.balance / wallet.balanceLimit).clamp(0.0, 1.0);
    final full = wallet.remainingLimit < 1;
    final busy = _paying || _verifying;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 12,
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: cs.onPrimary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                'Wallet balance',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _inr(wallet.balance),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: cs.onPrimary,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 6,
              backgroundColor: cs.onPrimary.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(cs.onPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_inr(wallet.balance, decimals: false)} of ${_inr(wallet.balanceLimit, decimals: false)}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onPrimary.withValues(alpha: 0.85),
                ),
              ),
              Text(
                full
                    ? 'Limit reached'
                    : '${_inr(wallet.remainingLimit, decimals: false)} left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: (full || busy) ? null : _openAddMoney,
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : const Icon(Icons.add, size: 20),
              label: Text(
                _verifying
                    ? 'Confirming payment...'
                    : full
                    ? 'Wallet is full'
                    : 'Add money',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.onPrimary,
                foregroundColor: cs.primary,
                disabledBackgroundColor: cs.onPrimary.withValues(alpha: 0.6),
                disabledForegroundColor: cs.primary.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingBanner(ColorScheme cs, _PendingVerify p) {
    final warn = context.appColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We could not confirm your payment of ${_inr(p.amount)} yet. '
              'Tap Retry. If it keeps failing, contact support with payment ID ${p.paymentId}.',
              style: TextStyle(fontSize: 12, color: cs.onSurface),
            ),
          ),
          TextButton(
            onPressed: _verifying ? null : () => _verify(p),
            child: Text(
              'Retry',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: cs.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add money to check out faster.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;

  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final credit = txn.isCredit;
    final fg = credit ? context.appColors.success : cs.error;
    final bg = fg.withValues(alpha: 0.15);
    final title = txn.description.isNotEmpty
        ? txn.description
        : (credit ? 'Money added' : 'Order payment');
    final subtitle = txn.orderNumber != null
        ? '${_formatDateTime(txn.createdAt)}  •  Order ${txn.orderNumber}'
        : _formatDateTime(txn.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: Icon(
              credit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 20,
              color: fg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${credit ? '+' : '−'}${_inr(txn.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMoneySheet extends StatefulWidget {
  final double remaining;
  final double limit;

  const _AddMoneySheet({required this.remaining, required this.limit});

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  static const _quick = [100.0, 500.0, 1000.0, 2000.0];

  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_controller.text.trim());

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter an amount';
    final amount = double.tryParse(text);
    if (amount == null || amount < 1) return 'Minimum amount is ₹1';
    if (amount > widget.remaining) {
      return 'You can add up to ${_inr(widget.remaining)}';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, double.parse(_amount!.toStringAsFixed(2)));
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = _amount;
    final valid = amount != null && _validate(_controller.text) == null;

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
              'Add money',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can add up to ${_inr(widget.remaining)}',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              validator: _validate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,5}(\.\d{0,2})?'),
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
                focusedBorder: _border(cs.primary, width: 2),
                errorBorder: _border(cs.error),
                focusedErrorBorder: _border(cs.error, width: 2),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final q in _quick)
                  if (q <= widget.remaining)
                    ActionChip(
                      label: Text(_inr(q, decimals: false)),
                      onPressed: () => _controller.text = q.toStringAsFixed(0),
                      backgroundColor: context.appColors.card,
                      side: BorderSide(color: context.appColors.border),
                      labelStyle: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  valid ? 'Pay ${_inr(amount)}' : 'Continue',
                  style: const TextStyle(
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
