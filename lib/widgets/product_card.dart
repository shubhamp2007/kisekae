import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String storeName;
  final double rating;
  final int price;
  final Alignment alignment;

  const ProductCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.price,
    this.storeName = '',
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasStore = storeName.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: alignment,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: colors.outlineVariant,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.image, size: 40, color: colors.outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                hasStore ? storeName : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasStore ? FontWeight.w500 : FontWeight.w400,
                  color: hasStore ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        if (hasStore)
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.onSurfaceVariant,
            ),
          ),
        Text(
          '₹$price',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
