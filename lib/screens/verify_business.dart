import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/screens/dashboard.dart';
import 'package:kisekae/services/store_verify.dart';

class VerifyBusinessScreen extends StatefulWidget {
  const VerifyBusinessScreen({super.key, required this.storeId});

  final int storeId;

  @override
  State<VerifyBusinessScreen> createState() => _VerifyBusinessScreenState();
}

class _VerifyBusinessScreenState extends State<VerifyBusinessScreen> {
  static const _addressMax = 200;
  static const _emailMax = 100;
  static const _refreshCooldownSeconds = 30;

  static final _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final _gstRegex = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  );
  static final _addressRegex = RegExp(
    r"^[\p{L}\p{N}][\p{L}\p{N} ,.\-/#()&'\n]*$",
    unicode: true,
  );
  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final _phoneRegex = RegExp(r'^[6-9]\d{9}$');

  final _storeRepository = StoreRepository();
  final _formKey = GlobalKey<FormState>();
  final _panController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitted = false;
  bool _isChecking = true;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isRefreshing = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _panController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _statusOf(Map<String, dynamic> data) =>
      (data['status'] ?? '').toString().toUpperCase().trim();

  Future<void> _loadStatus() async {
    try {
      final data = await _storeRepository.getBusinessVerification(
        storeId: widget.storeId,
      );
      if (!mounted) return;
      _applyStatus(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode != 404) _showMessage(e.message);
      setState(() => _isChecking = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChecking = false);
    }
  }

  void _applyStatus(Map<String, dynamic> data) {
    final status = _statusOf(data);

    switch (status) {
      case 'APPROVED':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SellerDashboardScreen(storeId: widget.storeId),
          ),
          (route) => false,
        );
        return;

      case 'PENDING':
        setState(() {
          _isChecking = false;
          _isSubmitted = true;
          _rejectionReason = null;
        });
        return;

      case 'REJECTED':
        final reason = data['rejection_reason']?.toString().trim() ?? '';
        if (_panController.text.isEmpty) {
          _panController.text = data['pan_number']?.toString() ?? '';
          _gstController.text = data['gst_number']?.toString() ?? '';
          _addressController.text = data['business_address']?.toString() ?? '';
          _emailController.text = data['business_email']?.toString() ?? '';
          _phoneController.text = (data['business_phone']?.toString() ?? '')
              .replaceAll(RegExp(r'\D'), '')
              .replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
        }
        setState(() {
          _isChecking = false;
          _isSubmitted = false;
          _rejectionReason = reason.isNotEmpty ? reason : 'Your verification was rejected. Please check your details and resubmit.';
        });
        return;

      default:
        setState(() {
          _isChecking = false;
          _isSubmitted = false;
          _rejectionReason = null;
        });
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _refreshCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing || _cooldownSeconds > 0) return;
    setState(() => _isRefreshing = true);
    try {
      final data = await _storeRepository.getBusinessVerification(
        storeId: widget.storeId,
      );
      debugPrint('REFRESH RESPONSE: $data');
      if (!mounted) return;
      final status = _statusOf(data);
      if (status != 'PENDING' && status != 'APPROVED' && status != 'REJECTED') {
        _showMessage('Could not read the verification status');
        return;
      }
      _applyStatus(data);
      if (status == 'PENDING') {
        _showMessage('Your verification is still under review');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e, st) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _startCooldown();
      }
    }
  }

  String? _validatePan(String? value) {
    final pan = value?.trim() ?? '';
    if (pan.isEmpty) return 'Enter your PAN number';
    if (!_panRegex.hasMatch(pan)) return 'Enter a valid PAN (e.g. ABCDE1234F)';
    return null;
  }

  String? _validateGst(String? value) {
    final gst = value?.trim() ?? '';
    if (gst.isEmpty) return 'Enter your GST number';
    if (!_gstRegex.hasMatch(gst)) return 'Enter a valid 15-character GSTIN';
    final pan = _panController.text.trim();
    if (_panRegex.hasMatch(pan) && gst.substring(2, 12) != pan) {
      return 'GSTIN does not match the PAN';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) return 'Enter your business address';
    if (address.length < 10) return 'Must be at least 10 characters';
    if (!_addressRegex.hasMatch(address)) {
      return 'Contains characters that are not allowed';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter a business phone number';
    if (!_phoneRegex.hasMatch(phone)) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter a business email';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final data = await _storeRepository.submitBusinessVerification(
        storeId: widget.storeId,
        panNumber: _panController.text.trim(),
        gstNumber: _gstController.text.trim(),
        businessAddress: _addressController.text
            .trim()
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n{2,}'), '\n'),
        businessPhone: _phoneController.text.trim(),
        businessEmail: _emailController.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      _applyStatus(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            enabled: !_isLoading,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            maxLength: maxLength,
            onFieldSubmitted: onFieldSubmitted,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefixText,
              helperText: ' ',
              errorMaxLines: 1,
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
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
        ],
      ),
    );
  }

  Widget _waitingView(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 24),
            Text(
              'Waiting for approval',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your business details have been submitted and are being reviewed. This may take some time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: cs.onSurface),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isRefreshing || _cooldownSeconds > 0)
                    ? null
                    : _refreshStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: _isRefreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _cooldownSeconds > 0
                      ? 'REFRESH IN ${_cooldownSeconds}s'
                      : 'REFRESH STATUS',
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

  Widget _formView(ColorScheme cs) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _rejectionReason!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.error,
                ),
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _field(
                  label: 'PAN Number',
                  hint: 'ABCDE1234F',
                  controller: _panController,
                  validator: _validatePan,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    TextInputFormatter.withFunction(
                      (old, value) =>
                          value.copyWith(text: value.text.toUpperCase()),
                    ),
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                _field(
                  label: 'GST Number',
                  hint: 'Enter 15-character GSTIN',
                  controller: _gstController,
                  validator: _validateGst,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    TextInputFormatter.withFunction(
                      (old, value) =>
                          value.copyWith(text: value.text.toUpperCase()),
                    ),
                    LengthLimitingTextInputFormatter(15),
                  ],
                ),
                _field(
                  label: 'Business Address',
                  hint: 'Enter your registered business address',
                  controller: _addressController,
                  validator: _validateAddress,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  maxLength: _addressMax,
                ),
                _field(
                  label: 'Business Phone',
                  hint: 'Enter 10-digit mobile number',
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixText: '+91 ',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                _field(
                  label: 'Business Email',
                  hint: 'Enter business email',
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(_emailMax),
                  ],
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: cs.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SUBMIT FOR VERIFICATION',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isSubmitted,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text(
            _isSubmitted ? 'VERIFICATION' : 'VERIFY YOUR BUSINESS',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
        body: SafeArea(
          child: _isChecking
              ? Center(child: CircularProgressIndicator(color: cs.primary))
              : _isSubmitted
              ? _waitingView(cs)
              : _formView(cs),
        ),
      ),
    );
  }
}
