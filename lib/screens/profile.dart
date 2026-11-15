import "package:flutter/material.dart";
import "package:kisekae/core/notifications/theme/app_theme.dart";
import "package:kisekae/screens/addresses.dart";
import "package:kisekae/screens/combos_screen.dart";
import "package:kisekae/screens/myorders_screen.dart";
import "package:kisekae/screens/onboarding_screen.dart";
import "package:kisekae/screens/personal_details.dart";
import "package:kisekae/screens/terms_conditions.dart";
import "package:kisekae/screens/wallet_screen.dart";
import "package:kisekae/screens/wishlist_screen.dart";
import "package:kisekae/services/account_service.dart";
import "package:kisekae/services/email_auth.dart";
import "package:kisekae/services/post_auth.dart";
import "package:kisekae/services/storage.dart";
import "package:kisekae/widgets/theme_toggle.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isSeller = false;
  bool _upgrading = false;

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

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      final response = await EmailAuth().logout();
      if (!mounted) return;
      if (response.success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
      if (response.message.isNotEmpty) {
        _showSnack(response.message, success: response.success);
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _openSellerSide() async {
    if (_upgrading) return;

    if (_isSeller) {
      await PostAuth.openSide(context, seller: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appColors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Become a seller?",
          style: TextStyle(color: ctx.cs.onSurface),
        ),
        content: Text(
          "Your account will be upgraded so you can create or join a store. "
          "You can still shop as a buyer at any time.",
          style: TextStyle(color: ctx.cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: ctx.appColors.mutedText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.cs.primary,
              foregroundColor: ctx.cs.onPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Continue"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _upgrading = true);
    final result = await AccountService().becomeSeller();
    if (!mounted) return;
    setState(() => _upgrading = false);

    if (!result.success) {
      _showSnack(result.message, success: false);
      return;
    }

    setState(() => _isSeller = true);
    await PostAuth.openSide(context, seller: true);
  }

  @override
  void initState() {
    super.initState();
    TokenStorage().readIsSeller().then((value) {
      if (mounted) setState(() => _isSeller = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
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
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        actions: const [ThemeToggle(), SizedBox(width: 16)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: iconChip(
                    Icons.inventory,
                    "Your orders",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyOrdersScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: iconChip(
                    Icons.favorite,
                    "Wishlist",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WishlistScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: iconChip(
                    Icons.checkroom,
                    "Saved combos",
                    iconSize: 24,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CombosScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: iconChip(
                    Icons.wallet,
                    "Wallet",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Profile Settings",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 32),
            actionChip(
              Icons.person_outline,
              "Personal information",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalInformationScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            actionChip(
              Icons.person_outline,
              "Addresses",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddressesScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            actionChip(
              Icons.storefront_outlined,
              _isSeller ? "Seller mode" : "Become a seller",
              isLoading: _upgrading,
              onTap: _upgrading ? null : _openSellerSide,
            ),
            const SizedBox(height: 16),
            actionChip(
              Icons.description_outlined,
              "Terms & conditions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            actionChip(
              Icons.meeting_room_outlined,
              "Logout",
              isLoading: _isLoggingOut,
              onTap: _isLoggingOut ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget iconChip(
    IconData icon,
    String label, {
    double iconSize = 18,
    VoidCallback? onTap,
  }) {
    final cs = context.cs;
    final c = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: c.card,
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionChip(
    IconData icon,
    String label, {
    double iconSize = 24,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final cs = context.cs;
    final c = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: c.card,
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: iconSize, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                )
              else
                Icon(Icons.arrow_forward, size: iconSize, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
