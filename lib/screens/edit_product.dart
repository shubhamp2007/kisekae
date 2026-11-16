import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/seller_product.dart';
import 'package:kisekae/screens/productgallery.dart';
import 'package:kisekae/services/seller_product.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final HandleProduct _productService = HandleProduct();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _comparePriceController;
  late TextEditingController _descriptionController;

  late String _selectedStatus;
  bool _isSaving = false;

  late List<_EditVariantData> _variantData;

  final List<String> _statusOptions = [
    'ACTIVE',
    'DRAFT',
    'LOW_STOCK',
    'OUT_OF_STOCK',
  ];

  static const _allSizes = ['XS', 'S', 'M', 'L', 'XL'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _skuController = TextEditingController(text: p.sku ?? '');
    _priceController = TextEditingController(text: p.price);
    _comparePriceController = TextEditingController(
      text: p.compareAtPrice ?? '',
    );
    _descriptionController = TextEditingController(text: p.description ?? '');
    _selectedStatus = _statusOptions.contains(p.status.toUpperCase())
        ? p.status.toUpperCase()
        : 'ACTIVE';

    _variantData = p.variants
        .map((v) => _EditVariantData.fromVariant(v))
        .toList();
    if (_variantData.isEmpty) {
      _variantData.add(_EditVariantData.empty());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _comparePriceController.dispose();
    _descriptionController.dispose();
    for (final v in _variantData) {
      v.dispose();
    }
    super.dispose();
  }

  List<VariantInput> _buildVariantInputs() {
    return _variantData.map((v) {
      final sizes = <ProductSizeInput>[];
      for (final s in _allSizes) {
        if (v.stockCtrls.containsKey(s)) {
          final stock = int.tryParse(v.stockCtrls[s]!.text.trim()) ?? 0;
          sizes.add(ProductSizeInput(size: s, stock: stock));
        }
      }
      return VariantInput(
        colorName: v.colorNameCtrl.text.trim(),
        colorHex: v.colorHexCtrl.text.trim(),
        sku: v.skuCtrl.text.trim().isEmpty ? null : v.skuCtrl.text.trim(),
        isActive: v.isActive,
        sizes: sizes,
      );
    }).toList();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedProduct = await _productService.updateProduct(
        storeId: widget.product.storeId,
        productId: widget.product.id,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isNotEmpty
            ? _skuController.text.trim()
            : null,
        price: _priceController.text.trim(),
        compareAtPrice: _comparePriceController.text.trim().isNotEmpty
            ? _comparePriceController.text.trim()
            : null,
        description: _descriptionController.text.trim(),
        status: _selectedStatus,
        variants: _buildVariantInputs(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
        Navigator.pop(context, updatedProduct);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update product: ${e.toString()}',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = colors.surface;
    final primaryColor = colors.primary;
    final cardBackgroundColor = context.appColors.card;
    final borderColor = colors.outlineVariant;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: colors.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: colors.onSurface,
            ),
          ),
        ),
        title: Text(
          "Edit Product",
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: "Product Name",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(controller: _skuController, label: "SKU"),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _priceController,
                            label: "Price (${widget.product.currency})",
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? "Price required"
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _comparePriceController,
                            label: "Compare Price",
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Status",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedStatus,
                                dropdownColor: cardBackgroundColor,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: _statusOptions
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _selectedStatus = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _descriptionController,
                      label: "Description",
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Variants",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _variantData.add(_EditVariantData.empty()),
                          ),
                          icon: Icon(Icons.add, color: primaryColor, size: 18),
                          label: Text(
                            'Add',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 12, color: borderColor),
                    for (var i = 0; i < _variantData.length; i++) ...[
                      _buildVariantCard(i, primaryColor),
                      if (i < _variantData.length - 1)
                        Divider(height: 20, color: borderColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Text(
                          "SAVE CHANGES",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(int index, Color primaryColor) {
    final colors = Theme.of(context).colorScheme;
    final v = _variantData[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tryParseHex(v.colorHexCtrl.text) ?? Colors.grey,
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.26),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Variant ${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
            Switch(
              value: v.isActive,
              activeColor: primaryColor,
              onChanged: (val) => setState(() => v.isActive = val),
            ),
            if (_variantData.length > 1)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: colors.error,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  _variantData[index].dispose();
                  _variantData.removeAt(index);
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: v.colorNameCtrl,
                label: "Colour Name",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                controller: v.colorHexCtrl,
                label: "Colour Hex",
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextField(controller: v.skuCtrl, label: "Variant SKU (optional)"),
        const SizedBox(height: 10),
        Text(
          "Stock per Size",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in _allSizes)
          if (v.stockCtrls.containsKey(s))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: v.stockCtrls[s],
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (v.id != null && v.id! > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductGalleryScreen(
                      storeId: widget.product.storeId,
                      productId: widget.product.id,
                      variantId: v.id!,
                      variantName: v.colorNameCtrl.text,
                      initialPrimaryImageUrl: v.thumbnail,
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.photo_library_outlined,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                "Manage Photos"
                "${v.imageCount > 0 ? ' (${v.imageCount})' : ''}",
                style: TextStyle(fontSize: 12, color: colors.primary),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: colors.primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color? _tryParseHex(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditVariantData {
  final int? id;
  final String? thumbnail;
  final int imageCount;
  final TextEditingController colorNameCtrl;
  final TextEditingController colorHexCtrl;
  final TextEditingController skuCtrl;
  bool isActive;
  final Map<String, TextEditingController> stockCtrls;

  _EditVariantData({
    this.id,
    this.thumbnail,
    this.imageCount = 0,
    required this.colorNameCtrl,
    required this.colorHexCtrl,
    required this.skuCtrl,
    required this.isActive,
    required this.stockCtrls,
  });

  factory _EditVariantData.fromVariant(ProductVariant variant) {
    final stockCtrls = <String, TextEditingController>{};
    for (final sz in variant.sizes) {
      stockCtrls[sz.size] = TextEditingController(text: sz.stock.toString());
    }
    return _EditVariantData(
      id: variant.id,
      thumbnail: variant.thumbnail,
      imageCount: variant.images.length,
      colorNameCtrl: TextEditingController(text: variant.colorName),
      colorHexCtrl: TextEditingController(text: variant.colorHex),
      skuCtrl: TextEditingController(text: variant.sku ?? ''),
      isActive: variant.isActive,
      stockCtrls: stockCtrls,
    );
  }

  factory _EditVariantData.empty() {
    return _EditVariantData(
      id: null,
      thumbnail: null,
      imageCount: 0,
      colorNameCtrl: TextEditingController(),
      colorHexCtrl: TextEditingController(text: '#'),
      skuCtrl: TextEditingController(),
      isActive: true,
      stockCtrls: {},
    );
  }

  void dispose() {
    colorNameCtrl.dispose();
    colorHexCtrl.dispose();
    skuCtrl.dispose();
    for (final c in stockCtrls.values) {
      c.dispose();
    }
  }
}
