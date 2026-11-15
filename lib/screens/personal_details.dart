import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/userprofile.dart';
import 'package:kisekae/screens/onboarding_screen.dart';
import 'package:kisekae/services/profile_details.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final ProfileDetails _userRepository = ProfileDetails();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isEditingName = false;
  bool _isSavingName = false;
  String? _errorMessage;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {required bool success}) {
    if (!mounted) return;
    final bg = success ? context.appColors.success : context.cs.error;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: fg)),
        backgroundColor: bg,
      ),
    );
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _userRepository.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile.name;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _profile?.name) {
      setState(() => _isEditingName = false);
      return;
    }

    setState(() => _isSavingName = true);

    try {
      final updatedProfile = await _userRepository.updateProfileName(newName);
      if (!mounted) return;
      setState(() {
        _profile = updatedProfile;
        _nameController.text = updatedProfile.name;
        _isEditingName = false;
        _isSavingName = false;
      });

      _showSnack("Name updated successfully!", success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingName = false);
      _showSnack(e.toString(), success: false);
    }
  }

  Future<void> _showDeactivateConfirmationDialog() async {
    bool isDeactivating = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDeactivating,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cs = context.cs;
            final c = context.appColors;

            return AlertDialog(
              backgroundColor: c.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: cs.outline),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    "Deactivate Account",
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Text(
                "Are you sure you confirm that you want to deactivate your account? This action will log you out and deactivate your profile.",
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeactivating
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: c.mutedText, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeactivating
                      ? null
                      : () async {
                          setDialogState(() => isDeactivating = true);

                          try {
                            final message = await _userRepository
                                .deleteAccount();

                            if (!mounted) return;
                            Navigator.pop(dialogContext);

                            Navigator.pushAndRemoveUntil(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => const OnboardingScreen(),
                              ),
                              (route) => false,
                            );

                            _showSnack(message, success: true);
                          } catch (e) {
                            setDialogState(() => isDeactivating = false);
                            _showSnack(e.toString(), success: false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: isDeactivating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onError,
                          ),
                        )
                      : Text(
                          "Confirm",
                          style: TextStyle(color: cs.onError, fontSize: 16),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
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
          "Personal Information",
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _showDeactivateConfirmationDialog,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 26,
                color: cs.error,
              ),
              tooltip: "Deactivate Account",
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final cs = context.cs;
    final c = context.appColors;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text("Retry", style: TextStyle(color: cs.onPrimary)),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: c.card,
      onRefresh: _fetchUserProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: c.card,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primary,
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.primary.withAlpha(179),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildNameTile(profile.name),

            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.email_outlined,
              label: "Email Address",
              value: profile.email,
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (profile.isEmailVerified ? c.success : c.warning)
                      .withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: profile.isEmailVerified ? c.success : c.warning,
                  ),
                ),
                child: Text(
                  profile.isEmailVerified ? "Verified" : "Unverified",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: profile.isEmailVerified ? c.success : c.warning,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.storefront_outlined,
              label: "Account Type",
              value: profile.isSeller ? "Seller Account" : "Buyer Account",
            ),
            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.calendar_today_outlined,
              label: "Member Since",
              value:
                  "${profile.dateJoined.day}/${profile.dateJoined.month}/${profile.dateJoined.year}",
            ),
            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.location_on_outlined,
              label: "Saved Addresses",
              value: "${profile.addressesCount} Saved",
            ),
            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.favorite_border,
              label: "Wishlist Items",
              value: "${profile.wishlistItemsCount} Items",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameTile(String currentName) {
    final cs = context.cs;
    final c = context.appColors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: c.card,
        border: Border.all(
          color: _isEditingName ? cs.primary : cs.outline,
          width: _isEditingName ? 2 : 1,
        ),
      ),
      child: _isEditingName
          ? Row(
              children: [
                Icon(Icons.person_outline, size: 22, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    enabled: !_isSavingName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Enter full name",
                    ),
                  ),
                ),
                if (_isSavingName)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                else ...[
                  IconButton(
                    icon: Icon(Icons.close, color: c.mutedText, size: 20),
                    onPressed: () {
                      setState(() {
                        _isEditingName = false;
                        _nameController.text = currentName;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: cs.primary, size: 22),
                    onPressed: _saveName,
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Icon(Icons.person_outline, size: 22, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Full Name",
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary.withAlpha(166),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingName = true;
                      _nameController.text = currentName;
                    });
                  },
                  icon: Icon(Icons.edit_outlined, size: 20, color: cs.primary),
                ),
              ],
            ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailingWidget,
  }) {
    final cs = context.cs;
    final c = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: c.card,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary.withAlpha(166),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}
