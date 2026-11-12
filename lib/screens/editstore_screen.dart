import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/store_create.dart';
import 'package:kisekae/services/store.dart';

class EditStoreScreen extends StatefulWidget {
  final Store store;

  const EditStoreScreen({super.key, required this.store});

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  static const _nameMax = 50;
  static const _descriptionMax = 200;
  static const _linkMax = 200;

  static final _nameRegex = RegExp(
    r"^[\p{L}\p{N}][\p{L}\p{N} &'.\-]*$",
    unicode: true,
  );
  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final _phoneRegex = RegExp(r'^[6-9]\d{9}$');

  final _storeOperations = StoreOperations();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _websiteController;
  late final TextEditingController _instagramController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  File? _newBanner;
  File? _newLogo;
  late bool _isActive;
  bool _isLoading = false;

  bool get _canToggleStatus =>
      widget.store.status == 'ACTIVE' || widget.store.status == 'INACTIVE';

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameController = TextEditingController(text: store.name);
    _descriptionController = TextEditingController(text: store.description);
    _websiteController = TextEditingController(text: store.websiteLink ?? '');
    _instagramController = TextEditingController(
      text: store.instagramLink ?? '',
    );
    _emailController = TextEditingController(text: store.contactEmail);
    final phoneDigits = store.contactPhone.replaceAll(RegExp(r'\D'), '');
    _phoneController = TextEditingController(
      text: phoneDigits.length > 10
          ? phoneDigits.substring(phoneDigits.length - 10)
          : phoneDigits,
    );
    _isActive = store.status == 'ACTIVE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your brand name';
    if (name.length < 3) return 'Must be at least 3 characters';
    if (!_nameRegex.hasMatch(name)) {
      return "Letters, numbers, spaces and & ' . - only";
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.isEmpty) return 'Enter a short description';
    if (description.length < 10) return 'Must be at least 10 characters';
    return null;
  }

  String? _validateOptionalLink(String? value) {
    final link = value?.trim() ?? '';
    if (link.isEmpty) return null;
    final uri = Uri.tryParse(link.contains('://') ? link : 'https://$link');
    if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) {
      return 'Enter a valid link';
    }
    return null;
  }

  String? _validateOptionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validateOptionalPhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!_phoneRegex.hasMatch(phone)) return 'Enter a valid 10-digit number';
    return null;
  }

  String _normalizeLink(String value) {
    final link = value.trim();
    if (link.isEmpty) return '';
    return link.contains('://') ? link : 'https://$link';
  }

  void _showMessage(String text, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: TextStyle(
              color: error
                  ? scheme.onError
                  : (isDark ? Colors.black : Colors.white),
            ),
          ),
          backgroundColor: error ? scheme.error : context.appColors.success,
        ),
      );
  }

  Future<void> _pickImage({required bool isBanner}) async {
    if (_isLoading) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        if (isBanner) {
          _newBanner = File(picked.path);
        } else {
          _newLogo = File(picked.path);
        }
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Could not open your gallery. Please try again',
        error: true,
      );
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final updated = await _storeOperations.updateStore(
        widget.store.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text
            .trim()
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n'),
        logo: _newLogo,
        banner: _newBanner,
        websiteLink: _normalizeLink(_websiteController.text),
        instagramLink: _normalizeLink(_instagramController.text),
        contactEmail: _emailController.text.trim().toLowerCase(),
        contactPhone: phone,
        status: _canToggleStatus ? (_isActive ? 'ACTIVE' : 'INACTIVE') : null,
      );
      if (!mounted) return;
      _showMessage('Store updated');
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, error: true);
    } catch (e, st) {
      print('UPDATE STORE ERROR: $e\n$st');
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _label(String text, {bool required = false, bool optional = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
          children: [
            if (required)
              TextSpan(
                text: '*',
                style: TextStyle(color: cs.error),
              ),
            if (optional)
              const TextSpan(
                text: '(Optional)',
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      enabled: !_isLoading,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      minLines: maxLines > 1 ? maxLines : null,
      maxLines: maxLines,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        prefixText: prefixText,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        disabledBorder: _border(Colors.transparent),
        focusedBorder: _border(cs.primary, width: 1.5),
        errorBorder: _border(cs.error),
        focusedErrorBorder: _border(cs.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        leading: IconButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
          'Edit Store',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, 2),
                  blurRadius: 8,
                  color: Color(0x14000000),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Store Banner'),
                  _ImageTile(
                    picked: _newBanner,
                    currentUrl: widget.store.bannerUrl,
                    hint: 'Banner recommended size(1200×400)',
                    enabled: !_isLoading,
                    onTap: () => _pickImage(isBanner: true),
                  ),
                  const SizedBox(height: 16),
                  _label('Store Logo'),
                  _ImageTile(
                    picked: _newLogo,
                    currentUrl: widget.store.logoUrl,
                    hint: 'Logo recommended size(512×512)',
                    enabled: !_isLoading,
                    onTap: () => _pickImage(isBanner: false),
                  ),
                  const SizedBox(height: 16),
                  _label('Brand Name', required: true),
                  _input(
                    controller: _nameController,
                    validator: _validateName,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_nameMax),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Brand Description', required: true),
                  _input(
                    controller: _descriptionController,
                    validator: _validateDescription,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    maxLength: _descriptionMax,
                  ),
                  const SizedBox(height: 8),
                  _label('Brand Website', optional: true),
                  _input(
                    controller: _websiteController,
                    validator: _validateOptionalLink,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(_linkMax),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Social Media links', optional: true),
                  _input(
                    controller: _instagramController,
                    validator: _validateOptionalLink,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(_linkMax),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Contact Email', optional: true),
                  _input(
                    controller: _emailController,
                    validator: _validateOptionalEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Contact Phone', optional: true),
                  _input(
                    controller: _phoneController,
                    validator: _validateOptionalPhone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    prefixText: '+91 ',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  if (_canToggleStatus) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: cs.primary,
                      value: _isActive,
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() => _isActive = value),
                      title: Text(
                        'Store is active',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Your store is visible to shoppers'
                            : 'Your store is hidden from shoppers',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: cs.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File? picked;
  final String? currentUrl;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  const _ImageTile({
    required this.picked,
    required this.currentUrl,
    required this.hint,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = currentUrl;
    final hasUrl = url != null && url.isNotEmpty;

    final Widget placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_camera_outlined, size: 28, color: cs.primary),
        const SizedBox(height: 8),
        Text(
          hint,
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    Widget content;
    if (picked != null) {
      content = Image.file(picked!, fit: BoxFit.cover, width: double.infinity);
    } else if (hasUrl) {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      content = placeholder;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (picked != null || hasUrl)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface.withValues(alpha: 0.9),
                  ),
                  child: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
