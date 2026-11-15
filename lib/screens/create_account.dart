import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/auth_response.dart';
import 'package:kisekae/screens/verify_code.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/services/oauth.dart';
import 'package:kisekae/services/post_auth.dart';
import 'package:kisekae/services/storage.dart';

class CreateAccount extends StatefulWidget {
  final bool isSeller;
  const CreateAccount({super.key, this.isSeller = false});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final _form = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _isOauthLoading = false;

  void _submitForm() async {
    if (_loading || _isOauthLoading) return;

    if (_form.currentState!.validate()) {
      setState(() => _loading = true);
      try {
        final email = _emailController.text.trim();
        final response = await EmailAuth().signUp(
          _nameController.text.trim(),
          email,
          _passwordController.text,
          isSeller: widget.isSeller,
        );
        if (!mounted) return;

        if (response.success) {
          await TokenStorage().saveEmail(email);
          if (!mounted) return;

          if (response.message.isNotEmpty) {
            final isDark =
                Theme.of(context).colorScheme.brightness == Brightness.dark;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.message,
                  style: TextStyle(color: isDark ? Colors.black : Colors.white),
                ),
                backgroundColor: context.appColors.success,
              ),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VerifyCodeScreen(email: email, isSeller: widget.isSeller),
            ),
          );
          return;
        }

        if (response.errorCode == 'REGISTRATION_PENDING') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VerifyCodeScreen(email: email, isSeller: widget.isSeller),
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
  }

  Future<void> _oauth(
    Future<AuthResponse> Function({required bool isSeller}) signIn,
  ) async {
    if (_loading || _isOauthLoading) return;
    setState(() => _isOauthLoading = true);
    try {
      final response = await signIn(isSeller: widget.isSeller);
      if (!mounted) return;

      if (response.success) {
        await PostAuth.afterAuth(context, response, picked: widget.isSeller);
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
      if (mounted) setState(() => _isOauthLoading = false);
    }
  }

  Future<void> _googleAuth() => _oauth(SocialAuth().signInWithGoogle);
  Future<void> _githubAuth() => _oauth(SocialAuth().signInWithGitHub);
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colors = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'sans-serif'),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: colors.onSurface, width: 2),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: colors.onSurface,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          centerTitle: true,
          title: Text(
            'Create Account',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: colors.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.065,
              vertical: size.height * 0.01,
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Start your style journey',

                      style: TextStyle(fontSize: size.width * 0.04),
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),

                  _inputField(
                    label: 'Full Name',
                    hintText: 'Enter your name',
                    controller: _nameController,
                    maxLength: 150,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters long';
                      }
                      if (value.length >= 150) {
                        return 'You have reached the maximum limit';
                      }
                      final nameRegex = RegExp(r'^[A-Za-z\s\.\ -]{2,150}$');
                      if (!nameRegex.hasMatch(value)) {
                        return 'Enter a valid name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.012),

                  _inputField(
                    label: 'Email',
                    hintText: 'Enter your email',
                    controller: _emailController,
                    maxLength: 100,
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

                      if (!emailRegex.hasMatch(value)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: size.height * 0.012),

                  _inputField(
                    label: 'Password',
                    hintText: 'Enter your password',
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
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (value.length >= 128) {
                        return 'You have reached the maximum limit';
                      }
                      final passwordRegex = RegExp(
                        r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,128}$',
                      );
                      if (!passwordRegex.hasMatch(value)) {
                        return 'Password must include a letter, a number, and a special character';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: size.height * 0.012),

                  _inputField(
                    label: 'Confirm password',
                    hintText: 'Confirm your password',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    maxLength: 128,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: colors.onSurface,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.035),

                  ElevatedButton(
                    onPressed: (_loading || _isOauthLoading)
                        ? null
                        : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: Size(double.infinity, size.height * 0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.onPrimary,
                            ),
                          )
                        : Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: size.width * 0.04,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  SizedBox(height: size.height * 0.04),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colors.onSurface, thickness: 0.8),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'or signup with',
                          style: TextStyle(
                            fontSize: size.width * 0.037,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: colors.onSurface, thickness: 0.8),
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.04),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: (_loading) ? null : _googleAuth,
                        child: CircleAvatar(
                          radius: 32,
                          // kept white on purpose: brand logos need a light backdrop
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset('assets/icons/google.png'),
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                      GestureDetector(
                        onTap: (_loading) ? null : _githubAuth,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset('assets/icons/github.png'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    FormFieldValidator<String>? validator,
    int? maxLength,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    final colors = Theme.of(context).colorScheme;
    final simpleBlackBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.onSurface, width: 1),
    );
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: size.width * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: size.height * 0.006),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: ' ',
            helperStyle: const TextStyle(height: 1),
            errorMaxLines: 2,
            errorStyle: const TextStyle(height: 1),
            counterText: '',
            hintStyle: TextStyle(fontSize: size.width * 0.04),
            contentPadding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.015,
            ),
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
