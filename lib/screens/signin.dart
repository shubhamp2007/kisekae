import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/models/auth_response.dart';
import 'package:kisekae/screens/password.dart';
import 'package:kisekae/services/oauth.dart';
import 'package:kisekae/services/post_auth.dart';

class Signin extends StatefulWidget {
  final bool isSeller;
  const Signin({super.key, this.isSeller = false});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _loading = false;
  bool _isOauthLoading = false;

  void _continue() {
    if (_isOauthLoading) return;
    if (_form.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SigninPassword(
            email: _emailController.text.trim(),
            isSeller: widget.isSeller,
          ),
        ),
      );
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
    _emailController.dispose();
    //_passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
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
        title: Text("Sign in", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            Text(
              'Hi, welcome back sign in to continue your styling journey',
              style: TextStyle(fontSize: size.width * 0.045),
            ),
            SizedBox(height: 16),
            Form(
              key: _form,
              child: Column(
                children: [
                  _TextInput(
                    label: 'Email',
                    hint: 'Enter your email',
                    maxLength: 100,
                    controller: _emailController,
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
                  SizedBox(height: size.height * 0.16),
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.065,
                    child: FilledButton(
                      onPressed: _isOauthLoading ? null : _continue,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'SIGN IN',
                        style: TextStyle(fontSize: size.width * 0.04),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.1),
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      SizedBox(width: 8),
                      Text(
                        "or signin with",
                        style: TextStyle(fontSize: size.width * 0.04),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: size.height * 0.1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isOauthLoading ? null : _googleAuth,
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
                        onTap: _isOauthLoading ? null : _githubAuth,
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
    ColorScheme colors = Theme.of(context).colorScheme;
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
