import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/screens/search.dart';

class KisekaeSearchBar extends StatelessWidget {
  final VoidCallback? onTap;

  const KisekaeSearchBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
          },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: colors.onSurface, size: 20),
            const SizedBox(width: 8),
            Text(
              "EXPLORE YOUR STYLE",
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
