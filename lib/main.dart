import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/core/notifications/theme/theme_controller.dart';
import 'package:kisekae/firebase_options.dart';
import 'package:kisekae/screens/getting_started.dart';
import 'package:kisekae/screens/home_screen.dart';
import 'package:kisekae/screens/season_sale_screen.dart';
import 'package:kisekae/screens/myorder_detail.dart';
import 'package:kisekae/screens/onboarding_screen.dart';
import 'package:kisekae/screens/tryon_history.dart';
import 'package:kisekae/core/notifications/background_handler.dart';
import 'package:kisekae/core/notifications/notification_service.dart';
import 'package:kisekae/screens/seller_gate_screen.dart';
import 'package:kisekae/services/profile_details.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await ThemeController.instance.load();
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

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool openSeller;
  const MyApp({super.key, required this.isLoggedIn, required this.openSeller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Kisekae',
          themeMode: mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          routes: {
            '/onboarding': (context) => OnboardingScreen(
              onThemeChanged: ThemeController.instance.setDark,
            ),
            '/seller-store': (context) => const SellerGateScreen(),
            '/login': (context) => const GettingStartedScreen(),
            '/home': (context) => const HomeScreen(),
            '/season-sale': (context) => const SeasonSaleScreen(),
          },
          onGenerateRoute: _generateRoute,
          home: _startScreen(),
        );
      },
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
    if (!isLoggedIn) {
      return OnboardingScreen(onThemeChanged: ThemeController.instance.setDark);
    }
    return openSeller ? const SellerGateScreen() : const HomeScreen();
  }
}