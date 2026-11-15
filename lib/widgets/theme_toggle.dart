import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/core/notifications/theme/theme_controller.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  static const double _width = 66;
  static const double _height = 34;
  static const double _thumb = 26;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;

        return Semantics(
          button: true,
          toggled: isDark,
          label: 'Dark mode',
          child: GestureDetector(
            onTap: ThemeController.instance.toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _width,
              height: _height,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.light_mode_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          Icon(
                            Icons.dark_mode_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: isDark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        size: 16,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
