import 'package:flutter/material.dart';

class BottomBar extends StatefulWidget {
  const BottomBar({super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _selectedIndex = 0;

  static const Color _barColor = Color(0xFF8B2E3E);
  static const Color _circleColor = Color(0xFFD9D9D9);

  Widget _selected(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: _circleColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _barColor, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        elevation: 0,
        backgroundColor: _barColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          Colors.transparent,
        ), // no focus/press circle
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: Colors.white,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_filled, color: Colors.white),
            selectedIcon: _selected(Icons.home_filled),
            label: 'HOME',
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps_rounded, color: Colors.white),
            selectedIcon: _selected(Icons.apps_rounded),
            label: 'CATEGORIES',
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            selectedIcon: _selected(Icons.shopping_cart),
            label: 'CART',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_rounded, color: Colors.white),
            selectedIcon: _selected(Icons.person_rounded),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }
}
