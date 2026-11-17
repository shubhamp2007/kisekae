import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/user_address.dart';
import 'package:kisekae/services/buyer_address.dart';

class EditAddressScreen extends StatefulWidget {
  final CustomerAddress address;

  const EditAddressScreen({super.key, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final AddressService _addressService = AddressService();

  late final TextEditingController _flatController;
  late final TextEditingController _areaController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _recipientNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _titleController;

  String? _selectedState;
  bool _isMyself = true;
  bool _isSaving = false;

  final List<String> _indianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    final addr = widget.address;

    _flatController = TextEditingController(text: addr.addressLine1);
    _areaController = TextEditingController(text: addr.addressLine2);
    _pincodeController = TextEditingController(
      text: addr.pinCode.isNotEmpty ? addr.pinCode : addr.postalCode,
    );
    _cityController = TextEditingController(text: addr.city);
    _recipientNameController = TextEditingController(text: addr.recipientName);
    _phoneController = TextEditingController(text: addr.phone);
    _titleController = TextEditingController(text: addr.title);
    if (_indianStates.contains(addr.state)) {
      _selectedState = addr.state;
    }
  }

  @override
  void dispose() {
    _flatController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _recipientNameController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _updateAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    if (_selectedState == null || _selectedState!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please select a state",
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final addressLine2Parts = <String>[];
      if (_areaController.text.trim().isNotEmpty) {
        addressLine2Parts.add(_areaController.text.trim());
      }

      await _addressService.updateAddress(
        addressId: widget.address.id,
        addressLine1: _flatController.text.trim(),
        addressLine2: addressLine2Parts.join(', '),
        postalCode: _pincodeController.text.trim(),
        city: _cityController.text.trim(),
        state: _selectedState!,
        recipientName: _recipientNameController.text.trim(),
        phone: _phoneController.text.trim(),
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : widget.address.title,
        isDefault: widget.address.isDefault,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Address updated successfully!",
            style: TextStyle(color: isDark ? Colors.black : Colors.white),
          ),
          backgroundColor: context.appColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryBurgundy = colors.primary;
    final pageBgColor = colors.surface;
    final cardBgColor = context.appColors.card;

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: pageBgColor,
        elevation: 0,
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
              size: 18,
              color: colors.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Edit Address",
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Address Details Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Address Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(
                        "Flat, House no., Building, Company, Apartment",
                      ),
                      _buildTextField(
                        controller: _flatController,
                        maxLength: 120,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Required field';
                          if (v.trim().length < 3)
                            return 'Must be at least 3 characters';
                          return null;
                        },
                      ),

                      _buildLabel("Area, Street, Sector, Village"),
                      _buildTextField(
                        controller: _areaController,
                        maxLength: 120,
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Pincode"),
                                _buildTextField(
                                  controller: _pincodeController,
                                  hintText: "6-digit Pincode",
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Required';
                                    if (!RegExp(r'^[1-9][0-9]{5}$')
                                        .hasMatch(v.trim())) {
                                      return 'Invalid Pincode';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Town/City"),
                                _buildTextField(
                                  controller: _cityController,
                                  maxLength: 50,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z\s]'),
                                    ),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Required';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      _buildLabel("State"),
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        isExpanded: true,
                        dropdownColor: context.appColors.card,
                        decoration: _inputDecoration(hintText: "Select"),
                        items: _indianStates.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(
                              state,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedState = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Details Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Contact Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isMyself = true),
                            child: Row(
                              children: [
                                Icon(
                                  _isMyself
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: colors.onSurface,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Myself",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () => setState(() => _isMyself = false),
                            child: Row(
                              children: [
                                Icon(
                                  !_isMyself
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: colors.onSurface,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Someone else",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildLabel("Reciever's Name"),
                      _buildTextField(
                        controller: _recipientNameController,
                        hintText: "Enter reciever's name",
                        maxLength: 50,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-Z\s\.\']"),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length < 2) return 'Name too short';
                          return null;
                        },
                      ),

                      _buildLabel("Reciever's phone number"),
                      _buildTextField(
                        controller: _phoneController,
                        hintText: "10-digit mobile number",
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                            return 'Enter valid 10-digit mobile no.';
                          }
                          return null;
                        },
                      ),

                      _buildLabel("Save address as"),
                      _buildTextField(
                        controller: _titleController,
                        hintText: "eg Home / Office / Other",
                        maxLength: 20,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s]'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _updateAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBurgundy,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Text(
                            "SAVE CHANGES",
                            style: TextStyle(
                              fontSize: 16,
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
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: _inputDecoration(hintText: hintText),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: context.appColors.mutedText, fontSize: 13),
      filled: true,
      counterText: "",
      fillColor: colors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    );
  }
}
