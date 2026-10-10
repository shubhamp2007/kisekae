import 'package:flutter/material.dart';
import 'package:kisekae/screens/getting_started.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kisekae/screens/onboarding_screen.dart';
import 'package:kisekae/services/dio.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisekae',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF8B2E3E),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF6F2532),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFFF2C2C),
          onError: Color(0xFFEAEAEA),
          surface: Color(0xFFEEE9E4),
          onSurface: Color(0xFF09090A),
          surfaceContainerHighest: Color(0XFFEEE0E2),
        ),
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      routes: {'/login': (context) => const GettingStartedScreen()},
      home: const OnboardingScreen(),
    );
  }
}
