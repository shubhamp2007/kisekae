import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:kisekae/models/api_exception.dart";
import "package:kisekae/models/seller_product.dart";
import "package:kisekae/services/seller_product.dart";

class _VariantData {
  final TextEditingController colorNameCtrl = TextEditingController();
  final TextEditingController colorHexCtrl = TextEditingController(text: '#');
  final TextEditingController skuCtrl = TextEditingController();
  final TextEditingController directStockCtrl = TextEditingController();
  final Set<String> selectedSizes = {};
  final Map<String, TextEditingController> stockCtrls = {
    for (final s in AddProductScreen._allSizes) s: TextEditingController(),
  };

  void dispose() {
    colorNameCtrl.dispose();
    colorHexCtrl.dispose();
    skuCtrl.dispose();
    directStockCtrl.dispose();
    for (final c in stockCtrls.values) {
      c.dispose();
    }
  }

  List<String> chosenSizes(List<String> available) => [
    for (final s in available)
      if (selectedSizes.contains(s)) s,
  ];
}

class AddProductScreen extends StatefulWidget {
  final int storeId;

  const AddProductScreen({super.key, required this.storeId});

  static const List<String> _clothingSizes = ['XS', 'S', 'M', 'L', 'XL'];
  static const List<String> _footwearSizes = [
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];
  static const List<String> _allSizes = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const _stepLabels = ['Details', 'Media', 'Variants', 'Review'];
  static const _wordLimit = 200;
  static const _maxImages = 10;
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

  static const _productTypes = <(String, String)>[
    ('Men', 'MEN'),
    ('Women', 'WOMEN'),
    ('Kids', 'KIDS'),
    ('Ethnic', 'ETHNIC'),
    ('Traditional', 'TRADITIONAL'),
    ('Formal', 'FORMAL'),
    ('Sports', 'SPORTS'),
  ];

  static const _categories = <(String, String)>[
    ('Top', 'TOP'),
    ('Bottom', 'BOTTOM'),
    ('One-Piece', 'ONE_PIECE'),
    ('Footwear', 'FOOTWEAR'),
    ('Headwear', 'HEADWEAR'),
    ('Eyewear', 'EYEWEAR'),
    ('Outerwear', 'OUTERWEAR'),
    ('Accessories', 'ACCESSORIES'),
  ];

  static final _nameRegex = RegExp(
    r"^[\p{L}\p{N}][\p{L}\p{N} &'.,\-()/]*$",
    unicode: true,
  );
  static final _skuRegex = RegExp(r'^[A-Za-z0-9\-_]{3,30}$');
  static final _priceRegex = RegExp(r'^\d{1,8}(\.\d{1,2})?$');
  static final _stockRegex = RegExp(r'^\d{1,6}$');
  static final _hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  final HandleProduct _productService = HandleProduct();
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  int? _createdProductId;
  int? _createdFirstVariantId;
  String? _createdStatus;
  bool _imagesUploaded = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  String? _productType = 'MEN';
  String? _category;

  bool get _hasNoSizes => _category == 'EYEWEAR' || _category == 'ACCESSORIES';

  List<String> get _currentSizes {
    if (_category == 'FOOTWEAR') {
      return AddProductScreen._footwearSizes;
    }
    if (_hasNoSizes) {
      return const [];
    }
    return AddProductScreen._clothingSizes;
  }

  final List<File> _images = [];
  final _picker = ImagePicker();

  final _priceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();

  final List<_VariantData> _variants = [_VariantData()];

  @override
  void initState() {
    super.initState();
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  int get _wordCount => _descCtrl.text.trim().isEmpty
      ? 0
      : _descCtrl.text.trim().split(RegExp(r'\s+')).length;

  void _msg(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String? _validateDetails() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'Please enter a product name';
    if (name.length < 3) return 'Product name must be at least 3 characters';
    if (!_nameRegex.hasMatch(name)) {
      return "Name can use letters, numbers, spaces and & ' . , - ( ) /";
    }
    if (_category == null) return 'Please select a category';
    if (_wordCount > _wordLimit) {
      return 'Description cannot be more than $_wordLimit words';
    }
    final sku = _skuCtrl.text.trim();
    if (sku.isNotEmpty && !_skuRegex.hasMatch(sku)) {
      return 'SKU must be 3-30 letters, numbers, - or _';
    }
    return null;
  }

  String? _validateMedia() {
    if (_images.isEmpty) return 'Please add at least one image';
    return null;
  }

  String? _validateVariants() {
    final price = _priceCtrl.text.trim();
    if (!_priceRegex.hasMatch(price) || double.parse(price) <= 0) {
      return 'Enter a valid price';
    }
    final mrp = _mrpCtrl.text.trim();
    if (mrp.isNotEmpty) {
      if (!_priceRegex.hasMatch(mrp)) return 'Enter a valid MRP';
      if (double.parse(mrp) < double.parse(price)) {
        return 'MRP cannot be less than the price';
      }
    }
    for (var i = 0; i < _variants.length; i++) {
      final v = _variants[i];
      final colorName = v.colorNameCtrl.text.trim();
      if (colorName.isEmpty) return 'Enter colour name for variant ${i + 1}';
      final colorHex = v.colorHexCtrl.text.trim();
      if (!_hexRegex.hasMatch(colorHex)) {
        return 'Enter a valid hex colour (#RRGGBB) for variant ${i + 1}';
      }
      if (_hasNoSizes) {
        final stock = v.directStockCtrl.text.trim();
        if (!_stockRegex.hasMatch(stock)) {
          return 'Enter stock quantity for variant ${i + 1}';
        }
      } else {
        final chosen = v.chosenSizes(_currentSizes);
        if (chosen.isEmpty) {
          return 'Select at least one size for variant ${i + 1}';
        }
        for (final s in chosen) {
          final stock = v.stockCtrls[s]!.text.trim();
          if (!_stockRegex.hasMatch(stock)) {
            return 'Enter stock quantity for size $s in variant ${i + 1}';
          }
        }
      }
    }
    return null;
  }

  void _goBack() {
    if (_isSubmitting) return;
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _goToNext() {
    final error = switch (_currentPage) {
      0 => _validateDetails(),
      1 => _validateMedia(),
      2 => _validateVariants(),
      _ => null,
    };
    if (error != null) return _msg(error);

    FocusScope.of(context).unfocus();
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isValidImage(File file) {
    final path = file.path.toLowerCase();
    return _allowedExtensions.any(path.endsWith) &&
        file.lengthSync() <= _maxImageBytes;
  }

  Future<void> _pickImages() async {
    if (_createdProductId != null) {
      return _msg('The product is already created, images cannot be changed');
    }
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return _msg('You can add up to $_maxImages images');

    final picked = await _picker.pickMultiImage(
      limit: remaining < 2 ? 2 : remaining,
    );
    if (picked.isEmpty) return;

    var skipped = 0;
    setState(() {
      for (final x in picked) {
        final file = File(x.path);
        if (_images.length < _maxImages && _isValidImage(file)) {
          _images.add(file);
        } else {
          skipped++;
        }
      }
    });
    if (skipped > 0) {
      _msg('$skipped image(s) skipped. Use JPG, PNG or WEBP up to 5 MB each');
    }
  }

  void _removeImage(int index) {
    if (_createdProductId != null) {
      return _msg('The product is already created, images cannot be changed');
    }
    setState(() => _images.removeAt(index));
  }

  List<VariantInput> _buildVariantInputs() {
    return [
      for (final v in _variants)
        VariantInput(
          colorName: v.colorNameCtrl.text.trim(),
          colorHex: v.colorHexCtrl.text.trim(),
          sku: v.skuCtrl.text.trim().isEmpty ? null : v.skuCtrl.text.trim(),
          isActive: true,
          sizes: _hasNoSizes
              ? const []
              : [
                  for (final s in v.chosenSizes(_currentSizes))
                    ProductSizeInput(
                      size: s,
                      stock: int.parse(v.stockCtrls[s]!.text.trim()),
                    ),
                ],
          stock: _hasNoSizes ? int.parse(v.directStockCtrl.text.trim()) : null,
        ),
    ];
  }

  Future<void> _submit(String status) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      var productId = _createdProductId;
      var firstVariantId = _createdFirstVariantId;

      if (productId == null) {
        final description = _descCtrl.text.trim();
        final sku = _skuCtrl.text.trim();
        final mrp = _mrpCtrl.text.trim();

        final request = CreateProductRequest(
          name: _nameCtrl.text.trim(),
          category: _category!,
          productType: _productType,
          description: description.isEmpty ? null : description,
          price: _priceCtrl.text.trim(),
          compareAtPrice: mrp.isEmpty ? null : mrp,
          sku: sku.isEmpty ? null : sku,
          status: status,
          variants: _buildVariantInputs(),
        );

        final created = await _productService.createProduct(
          storeId: widget.storeId,
          request: request,
        );
        productId = created.id;
        _createdProductId = productId;
        _createdStatus = status;
        if (created.variants.isNotEmpty) {
          firstVariantId = created.variants.first.id;
          _createdFirstVariantId = firstVariantId;
        }
      }

      if (!_imagesUploaded && _images.isNotEmpty && firstVariantId != null) {
        for (var i = 0; i < _images.length; i++) {
          await _productService.uploadVariantImage(
            storeId: widget.storeId,
            productId: productId,
            variantId: firstVariantId,
            imageFile: _images[i],
            order: i,
          );
        }
        _imagesUploaded = true;
      }

      if (!mounted) return;
      _msg(
        _createdStatus == 'ACTIVE'
            ? 'Product published'
            : 'Product saved as draft',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _msg(_failureMessage(e.message));
    } catch (_) {
      if (!mounted) return;
      _msg(_failureMessage('Something went wrong. Please try again'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _failureMessage(String reason) {
    if (_createdProductId == null) return reason;
    return 'Product saved, but the images were not uploaded: $reason. '
        'Tap the button again to retry.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _currentPage == _stepLabels.length - 1;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        leading: IconButton(
          onPressed: _goBack,
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: cs.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Add Products",
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _stepper(),
              const SizedBox(height: 20),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (v) => setState(() => _currentPage = v),
                  children: [
                    _detailsPage(),
                    _mediaPage(),
                    _variantsPage(),
                    _reviewPage(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : isLast
                      ? () => _submit('ACTIVE')
                      : _goToNext,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: cs.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isLast ? 'PUBLISH PRODUCT' : 'CONTINUE',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stepLabels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Divider(color: cs.primary, thickness: 1.5, height: 1),
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary,
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: i < _currentPage
                      ? cs.primary
                      : i == _currentPage
                      ? cs.surfaceContainerHighest
                      : cs.surface,
                  child: i < _currentPage
                      ? Icon(Icons.check, color: cs.onPrimary, size: 20)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(fontSize: 20, color: cs.onSurface),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 44,
                height: 20,
                child: OverflowBox(
                  maxWidth: 100,
                  child: Text(
                    _stepLabels[i],
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  InputDecoration _dec(String hint, {String? prefixText}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.onSurface),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.onSurface),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );

  Widget _imageBox({required Widget child, double? size, double radius = 16}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.onSurface),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius > 1 ? radius - 1 : radius),
        child: child,
      ),
    );
  }

  Widget _detailsPage() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Product Name'),
          TextField(
            controller: _nameCtrl,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            decoration: _dec('Enter product name'),
          ),
          const SizedBox(height: 16),
          _label('Description'),
          Stack(
            children: [
              TextField(
                controller: _descCtrl,
                maxLines: 6,
                decoration: _dec('Tell us about your product').copyWith(
                  contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 8,
                child: Text(
                  '$_wordCount/$_wordLimit words',
                  style: TextStyle(
                    color: _wordCount > _wordLimit ? cs.error : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Product Type'),
          DropdownButtonFormField<String>(
            initialValue: _productType,
            decoration: _dec('Select product type'),
            dropdownColor: cs.surfaceContainerHighest,
            items: [
              for (final t in _productTypes)
                DropdownMenuItem(value: t.$2, child: Text(t.$1)),
            ],
            onChanged: (v) => setState(() => _productType = v),
          ),
          const SizedBox(height: 16),
          _label('Category'),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _dec('Select category'),
            dropdownColor: cs.surfaceContainerHighest,
            items: [
              for (final c in _categories)
                DropdownMenuItem(value: c.$2, child: Text(c.$1)),
            ],
            onChanged: (v) {
              setState(() {
                if (_category != v) {
                  _category = v;
                  for (final variant in _variants) {
                    variant.selectedSizes.clear();
                  }
                }
              });
            },
          ),
          const SizedBox(height: 16),
          _label('SKU (optional)'),
          TextField(
            controller: _skuCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: _dec('Enter product code'),
          ),
        ],
      ),
    );
  }

  Widget _mediaPage() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Images',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload high quality images of your product',
            style: TextStyle(color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImages,
            child: CustomPaint(
              painter: _DashedBorderPainter(color: cs.onSurface),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: cs.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to Upload',
                      style: TextStyle(fontSize: 16, color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add up to $_maxImages images',
                      style: TextStyle(color: cs.onSurface),
                    ),
                    Text(
                      'JPG, PNG, WEBP (Max 5 MB Each)',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Uploaded Images',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Images will be uploaded to the first variant',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ],
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    Positioned.fill(
                      child: _imageBox(
                        child: Image.file(_images[i], fit: BoxFit.cover),
                      ),
                    ),
                    if (i == 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Main',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: cs.primary,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < _maxImages)
                GestureDetector(
                  onTap: _pickImages,
                  child: _imageBox(
                    child: Center(
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: cs.onSurface,
                        child: Icon(Icons.add, color: cs.surface, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _variantsPage() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Price'),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: _dec('Enter price', prefixText: '₹ '),
          ),
          const SizedBox(height: 16),
          _label('MRP (optional)'),
          TextField(
            controller: _mrpCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: _dec('Enter MRP', prefixText: '₹ '),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variants',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _variants.add(_VariantData())),
                icon: Icon(Icons.add, color: cs.primary),
                label: Text('Add Variant', style: TextStyle(color: cs.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _variants.length; i++) ...[
            _variantCard(i),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _variantCard(int index) {
    final cs = Theme.of(context).colorScheme;
    final v = _variants[index];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (_variants.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: cs.error),
                  onPressed: () => setState(() {
                    _variants[index].dispose();
                    _variants.removeAt(index);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _label('Colour Name'),
          TextField(
            controller: v.colorNameCtrl,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            decoration: _dec('e.g. Washed Charcoal'),
          ),
          const SizedBox(height: 12),
          _label('Colour Hex'),
          TextField(
            controller: v.colorHexCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: _dec('#RRGGBB'),
          ),
          const SizedBox(height: 12),
          _label('Variant SKU (optional)'),
          TextField(
            controller: v.skuCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: _dec('e.g. TEE-CHAR-01'),
          ),
          if (_hasNoSizes) ...[
            const SizedBox(height: 12),
            _label('Stock Quantity'),
            TextField(
              controller: v.directStockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _dec('Enter stock quantity'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _label('Sizes'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _currentSizes)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (!v.selectedSizes.remove(s)) v.selectedSizes.add(s);
                    }),
                    child: Container(
                      width: 52,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v.selectedSizes.contains(s)
                            ? cs.primary.withOpacity(0.15)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary,
                          width: v.selectedSizes.contains(s) ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(fontSize: 15, color: cs.onSurface),
                      ),
                    ),
                  ),
              ],
            ),
            if (v.chosenSizes(_currentSizes).isNotEmpty) ...[
              const SizedBox(height: 12),
              _label('Stock Quantity'),
              for (final s in v.chosenSizes(_currentSizes))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: v.stockCtrls[s],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: _dec('Stock for $s'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _reviewPage() {
    final cs = Theme.of(context).colorScheme;
    final productTypeLabel = _productTypes
        .where((t) => t.$2 == _productType)
        .map((t) => t.$1)
        .join();
    final categoryLabel = _categories
        .where((c) => c.$2 == _category)
        .map((c) => c.$1)
        .join();

    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: TextStyle(color: cs.onSurface)),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '-' : v,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review  & Publish',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_images.isNotEmpty)
                  _imageBox(
                    size: 72,
                    child: Image.file(_images.first, fit: BoxFit.cover),
                  ),
                heading('Basic Details'),
                row('Name', _nameCtrl.text.trim()),
                if (productTypeLabel.isNotEmpty)
                  row('Product Type', productTypeLabel),
                row('Category', categoryLabel),
                row('SKU', _skuCtrl.text.trim()),
                row('Description', _descCtrl.text.trim()),
                heading('Images'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _images)
                      _imageBox(
                        size: 64,
                        child: Image.file(f, fit: BoxFit.cover),
                      ),
                  ],
                ),
                heading('Pricing'),
                row(
                  'Price',
                  _priceCtrl.text.trim().isEmpty
                      ? ''
                      : '₹${_priceCtrl.text.trim()}',
                ),
                row(
                  'MRP',
                  _mrpCtrl.text.trim().isEmpty
                      ? ''
                      : '₹${_mrpCtrl.text.trim()}',
                ),
                heading('Variants (${_variants.length})'),
                for (var i = 0; i < _variants.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Variant ${i + 1}: ${_variants[i].colorNameCtrl.text.trim()} (${_variants[i].colorHexCtrl.text.trim()})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (_hasNoSizes)
                    row('  Stock', _variants[i].directStockCtrl.text.trim())
                  else
                    for (final s in _variants[i].chosenSizes(_currentSizes))
                      row('  Size $s', _variants[i].stockCtrls[s]!.text.trim()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}
