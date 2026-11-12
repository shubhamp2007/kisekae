import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';

import 'dart:async';

import 'package:kisekae/screens/new_password.dart';
import 'package:kisekae/services/email_auth.dart';

class PasswordOTP extends StatefulWidget {
  final String email;
  const PasswordOTP({super.key, required this.email});

  @override
  State<PasswordOTP> createState() => _PasswordOTPState();
}

class _PasswordOTPState extends State<PasswordOTP> {
  final int _otpLength = 6;
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  bool _hasError = false;
  bool _verifying = false;
  bool _resending = false;

  String get _code => _controllers.map((c) => c.text.trim()).join();
  String _errorText = '';

  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(_otpLength, (index) => FocusNode());
    _controllers = List.generate(
      _otpLength,
      (index) => TextEditingController(),
    );
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _showSnack(String message, {required bool success}) {
    final bg = success ? context.appColors.success : context.cs.error;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: fg)),
        backgroundColor: bg,
      ),
    );
  }

  void _onChanged(String value, int index) {
    if (_hasError) setState(() => _hasError = false);
    if (value.length > 1) {
      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength; i++) {
        if (i < digitsOnly.length) {
          _controllers[i].value = TextEditingValue(
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

  Future<void> _onVerify() async {
    if (_verifying || _resending) return;
    if (_code.length != _otpLength) {
      setState(() {
        _hasError = true;
        _errorText = "Please enter the full 6-digit code";
      });
      return;
    }

    setState(() {
      _hasError = false;
      _verifying = true;
    });

    try {
      final response = await EmailAuth().verifyOtp(
        widget.email,
        _code,
        purpose: "password_reset",
      );
      if (!mounted) return;

      if (response.success) {
        final resetToken = response.data?["reset_token"]?.toString() ?? "";
        if (resetToken.isEmpty) {
          _showSnack("Reset token missing from response", success: false);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(resetToken: resetToken),
          ),
        );
      } else {
        setState(() => _hasError = true);
        _errorText = "Incorrect code. Please try again.";
      }

      if (response.message.isNotEmpty) {
        _showSnack(response.message, success: response.success);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final response = await EmailAuth().sendOtp(
        widget.email,
        purpose: "password_reset",
      );
      if (!mounted) return;
      if (response.success) _startTimer();
      if (response.message.isNotEmpty) {
        _showSnack(response.message, success: response.success);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cs;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
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
        title: Text(
          "OTP Verification",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            Text(
              'We have sent a 6 digit code to ${_maskEmail(widget.email)}',
              style: TextStyle(
                fontSize: size.width * 0.045,
                color: colors.onSurface,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                _otpLength,
                (index) => SizedBox(
                  height: size.height * 0.09,
                  width: size.width * 0.125,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    autofocus: index == 0,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        1,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                      ),
                    ],
                    onChanged: (value) => _onChanged(value, index),
                    decoration: InputDecoration(
                      helperText: ' ',
                      helperStyle: const TextStyle(height: 1),
                      errorMaxLines: 1,
                      errorStyle: const TextStyle(height: 1),
                      counterText: "",
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_hasError)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _errorText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.error, fontSize: 14),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: TextStyle(
                    fontSize: size.width * 0.037,
                    color: colors.onSurface,
                  ),
                ),
                if (_secondsLeft > 0)
                  Text(
                    '0:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: size.width * 0.037,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: (_resending) ? null : _resendCode,
                    child: Text(
                      _resending ? 'Resending...' : 'Resend Code',
                      style: TextStyle(
                        fontSize: size.width * 0.037,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 68),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _verifying ? null : _onVerify,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _verifying
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
