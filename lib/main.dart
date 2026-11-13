import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kisekae/firebase_options.dart';
import 'package:kisekae/screens/getting_started.dart';
import 'package:kisekae/screens/home_screen.dart';
import 'package:kisekae/screens/season_sale_screen.dart';
import 'package:kisekae/screens/myorder_detail.dart';
import 'package:kisekae/screens/onboarding_screen.dart';
import 'package:kisekae/screens/seller_start.dart';
import 'package:kisekae/screens/tryon_history.dart';
import 'package:kisekae/core/notifications/background_handler.dart';
import 'package:kisekae/core/notifications/notification_service.dart';
import 'package:kisekae/screens/seller_gate_screen.dart';
import 'package:kisekae/screens/pose_screen.dart';

import 'package:kisekae/services/profile_details.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await DioClient.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  await NotificationService().initialize();
  await NotificationService().setupTokenRefresh(
    ProfileDetails().updateFCMToken,
  );

  final storage = TokenStorage();
  final token = await storage.readAccessToken();
  final bool isLoggedIn = token != null && token.isNotEmpty;

  final bool openSeller =
      isLoggedIn &&
      await storage.readIsSeller() &&
      await storage.readMode() == 'seller';

  runApp(MyApp(isLoggedIn: isLoggedIn, openSeller: openSeller));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool openSeller;
  const MyApp({super.key, required this.isLoggedIn, required this.openSeller});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _setDark(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8B2E3E),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF6F2532),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFFF2C2C),
    onError: Color(0xFFEAEAEA),
    surface: Color(0xFFEEE9E4),
    onSurface: Color(0xFF09090A),
    surfaceContainerHighest: Color(0xFFEEE0E2),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC4566A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFD9798A),
    onSecondary: Color(0xFF09090A),
    error: Color(0xFFFF5C5C),
    onError: Color(0xFF09090A),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFEEE9E4),
    surfaceContainerHighest: Color(0xFF2A2A2C),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisekae',
      themeMode: _themeMode,
      theme: ThemeData(colorScheme: _lightScheme),
      darkTheme: ThemeData(colorScheme: _darkScheme),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      routes: {
        '/onboarding': (context) => OnboardingScreen(onThemeChanged: _setDark),
        '/seller-store': (context) => const SellerGateScreen(),
        '/login': (context) => const GettingStartedScreen(),
        '/home': (context) => const HomeScreen(),
        '/season-sale': (context) => const SeasonSaleScreen(),
        '/pose': (context) => const PoseDetectionScreen(),
      },
      onGenerateRoute: _generateRoute,
      home: _startScreen(),
    );
  }

  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final orderMatch = RegExp(r'^/orders/(\d+)$').firstMatch(name);
    if (orderMatch != null) {
      final orderId = int.parse(orderMatch.group(1)!);
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => OrderDetailsScreen(orderId: orderId),
      );
    }

    final tryonMatch = RegExp(r'^/tryon/(.+)$').firstMatch(name);
    if (tryonMatch != null) {
      final requestId = tryonMatch.group(1)!;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => TryOnDeepLinkScreen(requestId: requestId),
      );
    }

    return null;
  }

  Widget _startScreen() {
    return const PoseDetectionScreen();
  }
}
