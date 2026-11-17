import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/screens/password_otp.dart';

class ForgotPassword extends StatefulWidget {
  final String email;
  const ForgotPassword({super.key, required this.email});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _sendingOtp = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_sendingOtp) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _sendingOtp = true);
    try {
      final email = _emailController.text.trim();
      final response = await EmailAuth().sendOtp(
        email,
        purpose: "password_reset",
      );

      if (!mounted) return;
      if (response.success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PasswordOTP(email: email)),
        );
      }
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
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final simpleBlackBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.onSurface, width: 1),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Container(
            padding: EdgeInsets.all(size.width * 0.01),
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
          "Forgot Password?",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.065,
              vertical: size.height * 0.01,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email address and we will send you a reset code',
                  style: TextStyle(fontSize: size.width * 0.045),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Email",
                          style: TextStyle(fontSize: size.width * 0.04),
                        ),
                      ],
                    ),
                    SizedBox(height: size.height * 0.01),
                    SizedBox(
                      child: TextFormField(
                        controller: _emailController,
                        maxLength: 100,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (value.length >= 100) {
                            return 'You have reached the maximum limit';
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.04,
                            vertical: size.height * 0.015,
                          ),
                          hintText: "Enter your email",
                          helperText: ' ',
                          helperStyle: const TextStyle(height: 1),
                          errorMaxLines: 1,
                          errorStyle: const TextStyle(height: 1),
                          counterText: '',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colors.onSurface,
                              width: 1,
                            ),
                          ),
                          enabledBorder: simpleBlackBorder,
                          focusedBorder: simpleBlackBorder,
                          errorBorder: simpleBlackBorder,
                          focusedErrorBorder: simpleBlackBorder,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.08),
                SizedBox(
                  width: double.infinity,
                  height: size.height * 0.065,
                  child: FilledButton(
                    onPressed: _sendingOtp ? null : _handleSendOtp,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sendingOtp
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Text(
                            'Send code',
                            style: TextStyle(fontSize: 16),
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
}
