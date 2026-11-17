import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/services/post_auth.dart';
import 'package:kisekae/services/storage.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final bool isSeller;

  const VerifyCodeScreen({
    super.key,
    required this.email,
    this.isSeller = false,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final int _otpLength = 6;
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  bool _hasError = false;
  bool _loading = false;
  bool _isResending = false;
  String _errorMessage = '';

  String get _code => _controllers.map((c) => c.text.trim()).join();

  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(
      _otpLength,
      (index) => FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
            setState(() {});
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
      ),
    );
    _controllers = List.generate(
      _otpLength,
      (index) => TextEditingController(),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
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

  void _onChanged(String value, int index) {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
    }

    if (value.length > 1) {
      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength; i++) {
        if (i < digitsOnly.length) {
          _controllers[i].text = digitsOnly[i];
        }
      }
      setState(() {});
      if (digitsOnly.length >= _otpLength) {
        _focusNodes[_otpLength - 1].unfocus();
        _verifyCode();
      } else if (digitsOnly.isNotEmpty) {
        _focusNodes[digitsOnly.length].requestFocus();
      }
      return;
    }

    setState(() {});

    if (value.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_code.length == _otpLength) {
          _verifyCode();
        }
      }
    } else if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_loading) return;

    if (_code.length != _otpLength) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter the full 6-digit code';
      });
      return;
    }

    setState(() {
      _loading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final response = await EmailAuth().verifyOtp(
      widget.email,
      _code,
      purpose: 'verify_email',
    );
    if (!mounted) return;
    setState(() => _loading = false);

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final successFg = isDark ? Colors.black : Colors.white;

    if (response.success) {
      await TokenStorage().saveEmail(widget.email);
      if (!mounted) return;

      if (response.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message, style: TextStyle(color: successFg)),
            backgroundColor: context.appColors.success,
          ),
        );
      }

      await PostAuth.afterAuth(context, response, picked: widget.isSeller);
    } else if (response.message.toLowerCase().contains('expired')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your sign-up expired. Please register again.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Verification failed. Please try again.';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage,
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _loading || _secondsLeft > 0) return;

    setState(() => _isResending = true);
    final response = await EmailAuth().sendOtp(
      widget.email,
      purpose: 'verify_email',
    );
    if (!mounted) return;
    setState(() => _isResending = false);

    if (response.success) {
      _startTimer();
      return;
    }

    if (response.errorCode == 'RATE_LIMIT_EXCEEDED') {
      final waitSeconds = response.errorDetails?['wait_seconds'];
      if (waitSeconds is int && waitSeconds > 0) {
        _startTimer(waitSeconds);
        return;
      }
    }

    final message = response.message.isNotEmpty
        ? response.message
        : 'Failed to resend code';
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: scheme.onError)),
        backgroundColor: scheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final maroon = colors.primary;
    final background = colors.surface;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.onSurface, width: 1.5),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 14,
              color: colors.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Verify your email',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: size.height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We have sent a 6 digit code to\n${_maskEmail(widget.email)}',
                style: TextStyle(fontSize: size.width * 0.04),
              ),
              SizedBox(height: size.height * 0.03),
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
                      onChanged: (value) => _onChanged(value, index),
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
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.error, fontSize: 14),
                  ),
                ),
              SizedBox(height: size.height * 0.04),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "didn't recieve the code? ",
                      style: TextStyle(fontSize: size.width * 0.037),
                    ),
                    if (_secondsLeft > 0)
                      Text(
                        'Resend (0:${_secondsLeft.toString().padLeft(2, '0')})',
                        style: TextStyle(
                          fontSize: size.width * 0.037,
                          color: maroon,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendCode,
                        child: Text(
                          _isResending ? 'Resending...' : 'Resend',
                          style: TextStyle(
                            fontSize: size.width * 0.037,
                            fontWeight: FontWeight.bold,
                            color: maroon,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: size.height * 0.04),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_loading || _code.length != _otpLength)
                      ? null
                      : _verifyCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: maroon,
                    disabledBackgroundColor: maroon,
                    foregroundColor: colors.onPrimary,
                    disabledForegroundColor: colors.onPrimary.withValues(
                      alpha: 0.7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
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
            ],
          ),
        ),
      ),
    );
  }
}
