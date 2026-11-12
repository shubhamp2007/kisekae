import 'package:flutter/material.dart';
import 'package:kisekae/screens/cart.dart';
import 'package:kisekae/screens/categories.dart';
import 'package:kisekae/screens/profile.dart';

class BottomBar extends StatelessWidget {
  final int selectedIndex;

  const BottomBar({super.key, this.selectedIndex = 0});

  Widget _selected(BuildContext context, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.primary, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        if (i == selectedIndex) {
          if (i == 1) {
            Navigator.popUntil(
              context,
              (route) => route.settings.name == '/categories' || route.isFirst,
            );
          }
          return;
        }

        switch (i) {
          case 0:
            Navigator.popUntil(context, (route) => route.isFirst);
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/categories'),
                builder: (_) => const CategoriesScreen(),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/cart'),
                builder: (_) => const CartScreen(),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/profile'),
                builder: (_) => const ProfileScreen(),
              ),
            );
            break;
        }
      },
      elevation: 0,
      backgroundColor: colors.primary,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(
        Colors.transparent,
      ), // no focus/press circle
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(color: colors.onPrimary, fontSize: 12, letterSpacing: 0.3),
      ),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_filled, color: colors.onPrimary),
          selectedIcon: _selected(context, Icons.home_filled),
          label: 'HOME',
        ),
        NavigationDestination(
          icon: Icon(Icons.apps_rounded, color: colors.onPrimary),
          selectedIcon: _selected(context, Icons.apps_rounded),
          label: 'CATEGORIES',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart, color: colors.onPrimary),
          selectedIcon: _selected(context, Icons.shopping_cart),
          label: 'CART',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_rounded, color: colors.onPrimary),
          selectedIcon: _selected(context, Icons.person_rounded),
          label: 'PROFILE',
        ),
      ],
    );
  }
}
