import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/services/post_auth.dart';
import 'package:kisekae/services/storage.dart';

class SigninOtp extends StatefulWidget {
  final String email;
  final bool isSeller;
  const SigninOtp({super.key, required this.email, required this.isSeller});

  @override
  State<SigninOtp> createState() => _SigninOtpState();
}

class _SigninOtpState extends State<SigninOtp> {
  final int _otpLength = 6;
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _otpControllers;

  String get _code => _otpControllers.map((c) => c.text.trim()).join();

  Timer? _timer;
  int _secondsLeft = 0;

  String _errorText = '';
  bool _hasError = false;
  bool _verifying = false;

  bool _resending = true;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _otpControllers = List.generate(_otpLength, (_) => TextEditingController());
    _sendOtp();
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    try {
      final response = await EmailAuth().sendOtp(widget.email);
      if (!mounted) return;
      if (response.success) _startTimer();
      if (response.message.isNotEmpty) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = scheme.brightness == Brightness.dark;
        final successFg = isDark ? Colors.black : Colors.white;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message,
              style: TextStyle(
                color: response.success ? successFg : scheme.onError,
              ),
            ),
            backgroundColor: response.success
                ? context.appColors.success
                : scheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resending || _verifying || _secondsLeft > 0) return;
    setState(() => _resending = true);
    await _sendOtp();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final visible = name.length <= 2 ? 1 : 2;
    final stars = (name.length - visible).clamp(1, 5);
    return '${name.substring(0, visible)}${'*' * stars}@${parts[1]}';
  }

  void _onOtpChanged(String value, int index) {
    if (_hasError) setState(() => _hasError = false);

    if (value.length > 1) {
      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength; i++) {
        if (i < digitsOnly.length) {
          _otpControllers[i].value = TextEditingValue(
            text: digitsOnly[i],
            selection: const TextSelection.collapsed(offset: 1),
          );
        }
      }
      if (digitsOnly.isNotEmpty) {
        final target = digitsOnly.length >= _otpLength
            ? _otpLength - 1
            : digitsOnly.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNodes[target].requestFocus();
        });
      }
      return;
    }

    if (value.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_verifying || _resending) return;
    if (_code.length != _otpLength) {
      setState(() {
        _hasError = true;
        _errorText = "Please enter the full 6-digit code";
      });
      return;
    }

    setState(() => _verifying = true);
    try {
      final response = await EmailAuth().verifyOtp(
        widget.email,
        _code,
        purpose: "login",
      );
      if (!mounted) return;
      if (response.success) {
        await TokenStorage().saveEmail(widget.email);
        if (!mounted) return;
        await PostAuth.afterAuth(context, response, picked: widget.isSeller);
        return;
      }
      setState(() {
        _hasError = true;
        _errorText = response.message.isNotEmpty
            ? response.message
            : "Incorrect code. Please try again.";
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final maroon = colors.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: colors.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: colors.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "OTP Verification",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'We have sent a 6 digit code to ${_maskEmail(widget.email)}',
                style: TextStyle(fontSize: size.width * 0.045),
              ),
            ),
            SizedBox(height: size.height * 0.03),

            // OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                _otpLength,
                (index) => SizedBox(
                  height: size.height * 0.09,
                  width: size.width * 0.125,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    autofocus: index == 0,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        1,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                      ),
                    ],
                    onChanged: (value) => _onOtpChanged(value, index),
                    decoration: InputDecoration(
                      helperText: ' ',
                      helperStyle: const TextStyle(height: 1),
                      counterText: "",
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colors.onSurface,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _hasError ? colors.error : colors.onSurface,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _hasError ? colors.error : colors.onSurface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_hasError)
              Padding(
                padding: EdgeInsets.only(top: size.height * 0.005),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.error, fontSize: 14),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: TextStyle(fontSize: size.width * 0.037),
                ),
                GestureDetector(
                  onTap: (_resending || _verifying || _secondsLeft > 0)
                      ? null
                      : _resendOtp,
                  child: Text(
                    _resending
                        ? 'Sending...'
                        : _secondsLeft > 0
                        ? 'Resend (0:${_secondsLeft.toString().padLeft(2, '0')})'
                        : 'Resend',
                    style: TextStyle(
                      fontSize: size.width * 0.037,
                      color: maroon,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: size.height * 0.03),

            TextButton(
              onPressed: (_verifying || _resending)
                  ? null
                  : () => Navigator.pop(context),
              child: Text(
                'Login with a password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size.width * 0.04,
                  color: colors.onSurface,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.02),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: size.height * 0.065,
              child: FilledButton(
                onPressed: (_verifying || _resending) ? null : _verifyOtp,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _verifying
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Text(
                        'Verify',
                        style: TextStyle(fontSize: size.width * 0.04),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
