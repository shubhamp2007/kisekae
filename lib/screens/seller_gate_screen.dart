import 'package:flutter/material.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/screens/dashboard.dart';
import 'package:kisekae/screens/multiple_stores.dart';
import 'package:kisekae/screens/seller_onboarding_screen.dart';
import 'package:kisekae/services/dio.dart';
import 'package:kisekae/services/post_auth.dart';
import 'package:kisekae/services/storage.dart';
import 'package:kisekae/services/store.dart';

class SellerGateScreen extends StatefulWidget {
  final int? openStoreId;

  const SellerGateScreen({super.key, this.openStoreId});

  @override
  State<SellerGateScreen> createState() => _SellerGateScreenState();
}

class _SellerGateScreenState extends State<SellerGateScreen> {
  final _storeOperations = StoreOperations();
  bool _triedRefresh = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _route();
  }

  bool _isNotSeller(ApiException e) =>
      e.statusCode == 403 && e.code == 'NOT_A_SELLER';

  void _replaceWith(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _route() async {
    setState(() => _error = null);
    try {
      final response = await _storeOperations.getStores(pageSize: 50);
      if (!mounted) return;
      final storage = TokenStorage();
      await storage.saveIsSeller(true);
      await storage.saveMode('seller');
      if (!mounted) return;

      final stores = response.results;

      final openId = widget.openStoreId;
      if (openId != null) {
        for (final store in stores) {
          if (store.id == openId && store.isBusinessVerified) {
            _replaceWith(SellerDashboardScreen(storeId: store.id));
            return;
          }
        }
      }

      if (stores.isEmpty) {
        _replaceWith(const SellerOnboardingScreen());
      } else {
        _replaceWith(MultipleStoresScreen(initialStores: stores));
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      if (_isNotSeller(e)) {
        if (!_triedRefresh) {
          _triedRefresh = true;
          final refreshed = await DioClient.refreshToken();
          if (!mounted) return;
          if (refreshed) return _route();
        }
        setState(
          () => _error =
              'Your seller account is not active yet. Please log in again.',
        );
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: _error == null
              ? CircularProgressIndicator(color: cs.primary)
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: cs.onSurface),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          _triedRefresh = false;
                          _route();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary),
                        ),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () =>
                            PostAuth.openSide(context, seller: false),
                        child: const Text('Go to shopping'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
