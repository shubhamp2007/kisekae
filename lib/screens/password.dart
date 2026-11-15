import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/screens/forgot_password.dart';
import 'package:kisekae/screens/signin_otp.dart';
import 'package:kisekae/screens/verify_code.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/services/post_auth.dart';
import 'package:kisekae/services/storage.dart';

class SigninPassword extends StatefulWidget {
  final String email;
  final bool isSeller;
  const SigninPassword({super.key, required this.email, this.isSeller = false});

  @override
  State<SigninPassword> createState() => _SigninPasswordState();
}

class _SigninPasswordState extends State<SigninPassword> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  Future<void> _submitForm() async {
    if (_loading) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final response = await EmailAuth().signIn(
        widget.email,
        _passwordController.text,
      );
      if (!mounted) return;

      if (response.success) {
        await TokenStorage().saveEmail(widget.email);
        if (!mounted) return;
        await PostAuth.afterAuth(context, response, picked: widget.isSeller);
        return;
      }

      if (response.message.toLowerCase().contains("email is not verified")) {
        final otpResponse = await EmailAuth().sendOtp(
          widget.email,
          purpose: "verify_email",
        );
        if (!mounted) return;
        if (otpResponse.message.isNotEmpty) {
          final scheme = Theme.of(context).colorScheme;
          final isDark = scheme.brightness == Brightness.dark;
          final successFg = isDark ? Colors.black : Colors.white;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                otpResponse.message,
                style: TextStyle(
                  color: otpResponse.success ? successFg : scheme.onError,
                ),
              ),
              backgroundColor: otpResponse.success
                  ? context.appColors.success
                  : scheme.error,
            ),
          );
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodeScreen(
              email: widget.email,
              isSeller: widget.isSeller,
            ),
          ),
        );
        return;
      }

      if (response.message.isNotEmpty) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message,
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

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
          "Sign in",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            Text(
              'Hi, welcome back sign in to continue your styling journey',
              style: TextStyle(fontSize: size.width * 0.045),
            ),
            const SizedBox(height: 16),

            // Password field
            Form(
              key: _form,
              child: _TextInput(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: 128,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: colors.onSurface,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length >= 128) {
                    return 'You have reached the maximum limit';
                  }
                  return null;
                },
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ForgotPassword(email: widget.email),
                          ),
                        );
                      },
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.normal,
                    fontSize: size.width * 0.04,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),

            SizedBox(height: size.height * 0.05),

            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SigninOtp(
                            email: widget.email,
                            isSeller: widget.isSeller,
                          ),
                        ),
                      );
                    },
              child: Text(
                'Login with OTP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size.width * 0.04,
                  color: colors.onSurface,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.02),

            SizedBox(
              width: double.infinity,
              height: size.height * 0.065,
              child: FilledButton(
                onPressed: _loading ? null : _submitForm,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Text(
                        'SIGN IN',
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

class _TextInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _TextInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.maxLength,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final simpleBlackBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: colors.onSurface, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: size.width * 0.04)),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: hint,
            helperText: ' ',
            helperStyle: const TextStyle(height: 1),
            errorMaxLines: 1,
            errorStyle: const TextStyle(height: 1),
            counterText: '',
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            border: simpleBlackBorder,
            enabledBorder: simpleBlackBorder,
            focusedBorder: simpleBlackBorder,
            errorBorder: simpleBlackBorder,
            focusedErrorBorder: simpleBlackBorder,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
