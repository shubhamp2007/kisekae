import 'package:flutter/material.dart';
import 'package:kisekae/models/auth_response.dart';
import 'package:kisekae/screens/seller_gate_screen.dart';
import 'package:kisekae/services/account_service.dart';
import 'package:kisekae/services/profile_details.dart';
import 'package:kisekae/services/storage.dart';

class PostAuth {
  static bool _serverIsSeller(AuthResponse r) {
    final user = r.data?['user'];
    return user is Map && user['is_seller'] == true;
  }

  static Future<void> afterAuth(
    BuildContext context,
    AuthResponse response, {
    required bool picked,
  }) async {
    var isSeller = _serverIsSeller(response);

    if (!isSeller && picked && response.data?['created'] == true) {
      final upgraded = await AccountService().becomeSeller();
      isSeller = upgraded.success;
    }

    await TokenStorage().saveIsSeller(isSeller);
    await ProfileDetails().registerCurrentFCMToken();
    if (!context.mounted) return;

    if (picked && !isSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is a buyer account. You can become a seller from your profile.',
          ),
        ),
      );
    }

    await openSide(context, seller: isSeller && picked);
  }

  static Future<void> openSide(
    BuildContext context, {
    required bool seller,
  }) async {
    await TokenStorage().saveMode(seller ? 'seller' : 'buyer');
    if (!context.mounted) return;

    if (seller) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellerGateScreen()),
        (_) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }
}
