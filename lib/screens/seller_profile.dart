import 'package:flutter/material.dart';
import 'package:kisekae/screens/analytics_screen.dart';
import 'package:kisekae/screens/mystore_screen.dart';
import 'package:kisekae/screens/seller_invite.dart';
import 'package:kisekae/screens/store_order.dart';
import 'package:kisekae/screens/team_access.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/services/post_auth.dart';

class ProfileScreen extends StatefulWidget {
  final int storeId;
  final String? myRole;

  const ProfileScreen({super.key, required this.storeId, this.myRole});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is not available yet')));
  }

  void _openTerms() {}

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrdersScreen(storeId: widget.storeId)),
    );
  }

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsScreen(storeId: widget.storeId),
      ),
    );
  }

  void _openStoreInformation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyStoreScreen(storeId: widget.storeId)),
    );
  }

  void _openTeamAccess() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TeamAccessScreen(storeId: widget.storeId, myRole: widget.myRole),
      ),
    );
  }

  void _openInvites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvitesScreen(storeId: widget.storeId)),
    );
  }

  void _openBuyerSide() {
    PostAuth.openSide(context, seller: false);
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          title: Text('Log out?', style: TextStyle(color: cs.onSurface)),
          content: Text(
            'You will need to log in again to access your store.',
            style: TextStyle(color: cs.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurface)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Log out',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) _logout();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    final response = await EmailAuth().logout();
    if (!response.success) {
      await DioClient.clearSession();
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  Widget _quickAction(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cs.surfaceContainerHighest,
      shape: StadiumBorder(side: BorderSide(color: cs.primary)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerHighest,
        shape: StadiumBorder(side: BorderSide(color: cs.primary)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: cs.primary),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: cs.primary,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(Icons.arrow_forward, size: 22, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final quickActions = <(IconData, String, VoidCallback)>[
      (Icons.inventory_2_outlined, 'Orders', _openOrders),
      (Icons.bar_chart, 'Analytics', _openAnalytics),
      (Icons.storefront, 'Store Information', _openStoreInformation),
      (Icons.groups, 'Team Access', _openTeamAccess),
    ];
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.2,
                children: [
                  for (final action in quickActions)
                    _quickAction(
                      cs,
                      icon: action.$1,
                      label: action.$2,
                      onTap: action.$3,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Profile settings',
                style: TextStyle(fontSize: 18, color: cs.onSurface),
              ),
              const SizedBox(height: 12),
              _settingTile(
                cs,
                icon: Icons.mail_outline,
                label: 'Invites',
                onTap: _openInvites,
              ),
              _settingTile(
                cs,
                icon: Icons.person,
                label: 'Business information',
                onTap: () => _comingSoon('Business information'),
              ),
              _settingTile(
                cs,
                icon: Icons.shopping_bag_outlined,
                label: 'Buyer mode',
                onTap: () => _openBuyerSide(),
              ),
              _settingTile(
                cs,
                icon: Icons.logout,
                label: 'Logout',
                isLoading: _isLoggingOut,
                onTap: _isLoggingOut ? null : _confirmLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
