import 'package:flutter/material.dart';
import 'package:kisekae/screens/create_account.dart';
import 'package:kisekae/screens/signin.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GettingStartedScreen extends StatelessWidget {
  final bool isSeller;

  const GettingStartedScreen({super.key, this.isSeller = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'sans-serif'),
      ),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.06,
              vertical: 20.0,
            ),
            child: Column(
              children: [
                SizedBox(height: size.height * 0.1),
                SvgPicture.asset(
                  'assets/images/pic1.svg',
                  height: size.height * 0.3,
                  fit: BoxFit.contain,
                  color: isDark ? null : scheme.surface,
                  colorBlendMode: BlendMode.multiply,
                ),

                SizedBox(height: size.height * 0.04),

                Text(
                  'Let’s Get Started',
                  style: TextStyle(
                    fontSize: size.width * 0.065,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),

                SizedBox(height: size.height * 0.04),

                Text(
                  'Sign in to your account or create a account',
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: size.height * 0.04),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Signin(isSeller: isSeller),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: Size(double.infinity, size.height * 0.065),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.02),

                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateAccount(isSeller: isSeller),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.primary,
                    minimumSize: Size(double.infinity, size.height * 0.065),
                    side: BorderSide(color: scheme.primary, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create An Account',
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
