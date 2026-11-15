import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';

class ProductFilters {
  final String? size;
  final String? color;
  final String? ordering;
  final double? minPrice;
  final double? maxPrice;

  const ProductFilters({
    this.size,
    this.color,
    this.ordering,
    this.minPrice,
    this.maxPrice,
  });

  bool get isEmpty =>
      size == null &&
      color == null &&
      ordering == null &&
      minPrice == null &&
      maxPrice == null;
}

class _ColorOption {
  final String name;
  final Color color;
  const _ColorOption(this.name, this.color);
}

class _SortOption {
  final String label;
  final String ordering;
  const _SortOption(this.label, this.ordering);
}

class FilterScreen extends StatefulWidget {
  final ProductFilters initialFilters;

  const FilterScreen({super.key, this.initialFilters = const ProductFilters()});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  static const double _priceMin = 0;
  static const double _priceMax = 20000;

  static const List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL'];

  static const List<_SortOption> _sortOptions = [
    _SortOption('Popular', 'top_rated'),
    _SortOption('Price-low to high', 'price'),
    _SortOption('Price-high to low', '-price'),
  ];

  // These are product-color swatches (data, not UI chrome), so they stay the
  // same in both themes on purpose: "Black" must look black, "White" cream, etc.
  static const List<_ColorOption> _colors = [
    _ColorOption('Pink', Color(0xFFE91EDB)),
    _ColorOption('Maroon', Color(0xFF8B2E3E)),
    _ColorOption('Teal', Color(0xFF5BB8BD)),
    _ColorOption('Orange', Color(0xFFE08A2B)),
    _ColorOption('Red', Color(0xFFE5202A)),
    _ColorOption('Yellow', Color(0xFFD9DB57)),
    _ColorOption('Purple', Color(0xFF6C5B9E)),
    _ColorOption('Green', Color(0xFF1F6B2E)),
    _ColorOption('White', Color(0xFFF2E8C9)),
    _ColorOption('Black', Color(0xFF000000)),
  ];

  String? _selectedSize;
  String? _selectedColor;
  String? _selectedOrdering;
  RangeValues _priceRange = const RangeValues(_priceMin, _priceMax);

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _selectedSize = f.size;
    _selectedColor = f.color;
    _selectedOrdering = f.ordering;
    _priceRange = RangeValues(
      (f.minPrice ?? _priceMin).clamp(_priceMin, _priceMax),
      (f.maxPrice ?? _priceMax).clamp(_priceMin, _priceMax),
    );
  }

  void _reset() {
    setState(() {
      _selectedSize = null;
      _selectedColor = null;
      _selectedOrdering = null;
      _priceRange = const RangeValues(_priceMin, _priceMax);
    });
  }

  void _apply() {
    final priceChanged =
        _priceRange.start != _priceMin || _priceRange.end != _priceMax;

    Navigator.pop(
      context,
      ProductFilters(
        size: _selectedSize,
        color: _selectedColor,
        ordering: _selectedOrdering,
        minPrice: _priceRange.start > _priceMin ? _priceRange.start : null,
        maxPrice: priceChanged && _priceRange.end < _priceMax
            ? _priceRange.end
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.onSurface, width: 2),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "Filter",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Size"),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _sizes
                          .map(
                            (size) => _chip(
                              label: size,
                              isSelected: _selectedSize == size,
                              minWidth: 44,
                              onTap: () => setState(() {
                                _selectedSize = _selectedSize == size
                                    ? null
                                    : size;
                              }),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle("Sort by"),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _sortOptions
                          .map(
                            (option) => _chip(
                              label: option.label,
                              isSelected: _selectedOrdering == option.ordering,
                              onTap: () => setState(() {
                                _selectedOrdering =
                                    _selectedOrdering == option.ordering
                                    ? null
                                    : option.ordering;
                              }),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle("Color"),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: _colors.map((option) {
                        final isSelected = _selectedColor == option.name;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedColor = isSelected ? null : option.name;
                          }),
                          child: Container(
                            width: 26,
                            height: 26,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: option.color,
                                // Thin outline so the Black swatch stays
                                // visible on the dark background.
                                border: Border.all(color: c.border),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle("Price Range"),
                    const SizedBox(height: 4),
                    Text(
                      "Selected Price range",
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₹${_priceRange.start.round()}  to  ₹${_priceRange.end.round()}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: cs.onSurface,
                        inactiveTrackColor: cs.onSurface.withAlpha(66),
                        thumbColor: cs.onSurface,
                        overlayColor: cs.onSurface.withAlpha(31),
                        trackHeight: 2,
                      ),
                      child: RangeSlider(
                        values: _priceRange,
                        min: _priceMin,
                        max: _priceMax,
                        divisions: 200,
                        onChanged: (values) =>
                            setState(() => _priceRange = values),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          backgroundColor: c.card,
                          side: BorderSide(color: cs.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Reset",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _apply,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Apply",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: context.cs.onSurface,
    ),
  );

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    double minWidth = 0,
  }) {
    final cs = context.cs;
    final c = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Color.alphaBlend(cs.primary.withAlpha(89), c.card)
              : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? cs.primary : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? cs.primary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}
