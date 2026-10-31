import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/cart.dart';
import 'package:kisekae/models/checkout.dart';
import 'package:kisekae/models/user_address.dart';
import 'package:kisekae/screens/home_screen.dart';
import 'package:kisekae/screens/trackorderscreen.dart';
import 'package:kisekae/services/buyer_address.dart';
import 'package:kisekae/services/checkout_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class _PaymentMethod {
  final String label;

  final String? iconAsset;

  const _PaymentMethod(this.label, {this.iconAsset});
}

class CheckoutScreen extends StatefulWidget {
  final CartModel cart;

  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _primaryColor = Color(0xFF8B2E3E);
  static const double _platformFee = 20;
  static const int _estimatedDeliveryDays = 5;

  static const List<_PaymentMethod> _paymentMethods = [
    _PaymentMethod('Credit Card', iconAsset: 'assets/icons/creditcard.png'),
    _PaymentMethod('UPI', iconAsset: 'assets/icons/googlepay.png'),
    _PaymentMethod('Pay Pal', iconAsset: 'assets/icons/paypal.png'),
  ];

  final PageController _controller = PageController();
  final AddressService _addressService = AddressService();
  final CheckoutService _checkoutService = CheckoutService();
  late final Razorpay _razorpay;

  CancelToken? _cancelToken;
  CustomerAddress? _selectedAddress;
  CheckoutResponse? _result;

  int _currentPage = 0;
  int _selectedMethod = 2;
  bool _isLoadingAddress = true;
  bool _isPlacingOrder = false;

  String get _razorpayKey => dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _loadAddress();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _cancelToken?.cancel("CheckoutScreen disposed");
    _controller.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await _addressService.getAddresses(
        cancelToken: _cancelToken,
      );
      CustomerAddress? selected;
      if (addresses.isNotEmpty) {
        selected = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedAddress = selected;
        _isLoadingAddress = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() => _isLoadingAddress = false);
    }
  }

  double get _mrpTotal {
    double total = 0;
    for (final item in widget.cart.items) {
      final comparePrice =
          double.tryParse(item.product.compareAtPrice ?? '') ??
          double.tryParse(item.product.price) ??
          0;
      total += comparePrice * item.quantity;
    }
    return total;
  }

  double get _subtotal => double.tryParse(widget.cart.subtotal) ?? 0;

  double get _discountTotal {
    final diff = _mrpTotal - _subtotal;
    return diff > 0 ? diff : 0;
  }

  double get _totalAmount => _subtotal;

  String get _deliveryText {
    final date = DateTime.now().add(
      const Duration(days: _estimatedDeliveryDays),
    );
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return 'Delivery by ${days[date.weekday - 1]}, '
        '${date.day} ${months[date.month - 1]}';
  }

  String _formatAddress(CustomerAddress? address) {
    if (address == null) return 'No address added';
    final parts = [
      if (address.addressLine1.isNotEmpty) address.addressLine1,
      if (address.addressLine2.isNotEmpty) address.addressLine2,
      if (address.city.isNotEmpty) address.city,
      if (address.pinCode.isNotEmpty)
        address.pinCode
      else if (address.postalCode.isNotEmpty)
        address.postalCode,
    ];
    return parts.join(', ');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onContinue() async {
    if (_currentPage == 0) {
      if (_selectedAddress == null) {
        _showSnack('Please add a delivery address');
        return;
      }
      _nextPage();
    } else if (_currentPage == 1) {
      await _placeOrder();
    } else {
      _goHome();
    }
  }

  Future<void> _placeOrder() async {
    final address = _selectedAddress;
    if (address == null || _isPlacingOrder) {
      if (address == null) _showSnack('Please add a delivery address');
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final result = await _checkoutService.checkoutCart(
        addressId: address.id,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isPlacingOrder = false;
      });

      if (result.requiresRazorpay) {
        final orderWithPayment = result.orders.firstWhere(
          (o) => o.razorpayOrderId.isNotEmpty,
        );
        _openRazorpay(orderWithPayment);
      } else {
        _nextPage();
      }
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() => _isPlacingOrder = false);
      _showSnack(e is ApiException ? e.message : 'Could not place your order');
    }
  }

  void _openRazorpay(CheckoutOrder order) {
    final amountInPaise = (double.tryParse(order.totalAmount) ?? 0) * 100;

    final options = <String, dynamic>{
      'key': _razorpayKey,
      'amount': amountInPaise.toInt(),
      'currency': order.currency.isNotEmpty ? order.currency : 'INR',
      'order_id': order.razorpayOrderId,
      'name': 'KiseKae',
      'description': 'Order #${order.orderNumber}',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#8B2E3E'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _showSnack('Could not open payment gateway. Please try again.');
      setState(() => _isPlacingOrder = false);
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    final result = _result;
    if (result == null) return;

    final order = result.orders.firstWhere(
      (o) => o.razorpayOrderId == response.orderId,
      orElse: () => result.orders.first,
    );

    setState(() => _isPlacingOrder = true);
    try {
      await _checkoutService.verifyPayment(
        orderId: order.orderId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? '',
        razorpaySignature: response.signature ?? '',
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      _nextPage();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      _showSnack(
        e is ApiException
            ? e.message
            : 'Payment received but verification failed. Contact support.',
      );
      _nextPage();
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isPlacingOrder = false);
    _showSnack(
      response.message?.isNotEmpty == true
          ? 'Payment failed: ${response.message}'
          : 'Payment was cancelled or failed. Please try again.',
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnack('External wallet selected: ${response.walletName}');
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _goToTrackOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrackOrderScreen(orderId: _result!.orders.first.orderId),
      ),
    );
  }

  void _handleBack() {
    if (_isPlacingOrder) return;
    if (_currentPage == 2) {
      _goHome();
    } else if (_currentPage == 1) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBack,
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
            "CHECKOUT",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStepper(),
                const SizedBox(height: 20),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (value) =>
                        setState(() => _currentPage = value),
                    children: [
                      _buildReviewPage(),
                      _buildPaymentPage(),
                      _buildConfirmPage(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_currentPage == 2) ...[
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _goToTrackOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: const BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'TRACK ORDER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _isPlacingOrder ? null : _onContinue,
                    child: _isPlacingOrder
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentPage < 2 ? 'CONTINUE' : 'CONTINUE SHOPPING',
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
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Divider(color: _primaryColor, thickness: 2),
                ),
              ),
            Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: i < _currentPage
                      ? _primaryColor
                      : i == _currentPage
                      ? const Color(0xFFDBBEC3)
                      : Colors.white,
                  child: i < _currentPage
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  ['Review', 'Payment', 'Order\nconfirm'][i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    final addressTitle = _selectedAddress?.title.trim() ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order summary', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          for (final item in widget.cart.items) ...[
            _productCard(item),
            const SizedBox(height: 12),
          ],
          _priceSummary(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoadingAddress
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryColor,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        'Address',
                        [
                          if (addressTitle.isNotEmpty)
                            addressTitle.toUpperCase(),
                          _formatAddress(_selectedAddress),
                        ].join('\n'),
                      ),
                      const SizedBox(height: 8),
                      _infoRow('Date', _deliveryText),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPaymentPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < _paymentMethods.length; i++)
            GestureDetector(
              onTap: () => setState(() => _selectedMethod = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: _paymentMethods[i].iconAsset != null
                          ? Image.asset(_paymentMethods[i].iconAsset!)
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        _paymentMethods[i].label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      _selectedMethod == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          _priceSummary(),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                'Secured by Razorpay',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPage() {
    final orderNumbers =
        _result?.orders
            .map((o) => o.orderNumber)
            .where((n) => n.isNotEmpty)
            .join(', ') ??
        '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: _primaryColor,
          child: Icon(Icons.check, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Thank you!!', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        const Text(
          'Your order has been placed successfully',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        const Text('ORDER NUMBER', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          orderNumbers,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 24),
        const Text(
          'You will receive an email with your order details',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _priceSummary() {
    final rows = [
      ['MRP', '₹${_mrpTotal.toInt()}'],
      ['Discounts', '-₹${_discountTotal.toInt()}'],
      ['Total amount', '₹${_totalAmount.toInt()}'],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row[0],
                    style: TextStyle(
                      fontWeight: row[0] == 'Total amount'
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    row[1],
                    style: TextStyle(
                      color: row[0] == 'Discounts' ? Colors.green : null,
                      fontWeight: row[0] == 'Total amount'
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _productCard(CartItem item) {
    final imagePath =
        item.product.imageUrl ??
        item.product.thumbnail ??
        'assets/images/clothes/4.jpg';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD3C7B8)),
      ),
      child: Row(
        children: [
          Container(
            height: 140,
            width: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _primaryColor, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagePath.startsWith('http')
                ? Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/clothes/4.jpg',
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                if (item.size.isNotEmpty)
                  Text(
                    'Size - ${item.size}',
                    style: const TextStyle(fontSize: 16),
                  ),
                Text(
                  'Price - ₹${item.product.price}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Quantity - ${item.quantity}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
