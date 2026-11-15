import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';

import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/store_create.dart';
import 'package:kisekae/screens/dashboard.dart';
import 'package:kisekae/screens/seller_onboarding_screen.dart';
import 'package:kisekae/screens/verify_business.dart';
import 'package:kisekae/services/store.dart';

class MultipleStoresScreen extends StatefulWidget {
  final List<Store>? initialStores;

  const MultipleStoresScreen({super.key, this.initialStores});

  @override
  State<MultipleStoresScreen> createState() => _MultipleStoresScreenState();
}

class _MultipleStoresScreenState extends State<MultipleStoresScreen> {
  final _storeOperations = StoreOperations();

  late List<Store> _stores;
  late bool _isLoading;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialStores != null && widget.initialStores!.isNotEmpty) {
      _stores = List.from(widget.initialStores!);
      _isLoading = false;
    } else {
      _stores = [];
      _isLoading = true;
      _loadStores();
    }
  }

  Future<void> _loadStores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _storeOperations.getStores(pageSize: 50);
      if (!mounted) return;
      setState(() => _stores = response.results);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load your stores');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isOwner(Store store) => store.myRole.toUpperCase() == 'OWNER';

  bool _isAwaitingOwner(Store store) =>
      !store.isBusinessVerified && !_isOwner(store);

  String _buttonLabel(Store store) {
    if (store.isBusinessVerified) return 'Open Dashboard';
    return _isOwner(store) ? 'Verify Business' : 'Awaiting Owner Verification';
  }

  void _openStore(Store store) {
    if (store.isBusinessVerified) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => SellerDashboardScreen(storeId: store.id),
        ),
        (route) => false,
      );
    } else if (_isOwner(store)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyBusinessScreen(storeId: store.id),
        ),
      ).then((_) => _loadStores());
    }
  }

  void _openCreateOrJoinScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SellerOnboardingScreen()),
    ).then((_) => _loadStores());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a store to manage its products, orders and performance',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildStoresList(cs)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _openCreateOrJoinScreen,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Create or join new store',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoresList(ColorScheme cs) {
    if (_isLoading && _stores.isEmpty) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null && _stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadStores,
              child: Text('Retry', style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _stores.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final store = _stores[index];
        return _buildStoreCard(cs, store);
      },
    );
  }

  Widget _buildStoreCard(ColorScheme cs, Store store) {
    final firstLetter = store.name.isNotEmpty
        ? store.name[0].toUpperCase()
        : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primary.withValues(alpha: 0.2),
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.description.isNotEmpty
                          ? store.description
                          : (store.isBusinessVerified
                                ? 'Verified Business'
                                : 'Pending Verification'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _isAwaitingOwner(store)
                  ? null
                  : () => _openStore(store),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                disabledBackgroundColor: cs.primary.withValues(alpha: 0.4),
                disabledForegroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _buttonLabel(store),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
