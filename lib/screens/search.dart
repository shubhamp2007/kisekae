import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/autocomplete.dart';
import 'package:kisekae/models/history.dart';
import 'package:kisekae/screens/product_screen.dart';

import 'package:kisekae/screens/products_list.dart';
import 'package:kisekae/services/search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _productService = SearchService();
  final TextEditingController _searchController = TextEditingController();

  CancelToken? _cancelToken;
  CancelToken? _autocompleteCancelToken;
  Timer? _debounceTimer;

  List<SearchHistoryItem> _history = [];
  bool _isLoadingHistory = true;
  bool _isClearing = false;

  AutocompleteData? _autocompleteData;
  bool _isLoadingAutocomplete = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _cancelToken?.cancel("SearchScreen disposed");
    _autocompleteCancelToken?.cancel("SearchScreen disposed");
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    _cancelToken?.cancel("Reloading history");
    _cancelToken = CancelToken();

    try {
      final items = await _productService.getSearchHistory(
        cancelToken: _cancelToken,
      );
      items.sort((a, b) {
        final aDate = a.lastSearchedAt ?? a.createdAt;
        final bDate = b.lastSearchedAt ?? b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      if (!mounted) return;
      setState(() {
        _history = items;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  void _onSearchChanged(String rawQuery) {
    _debounceTimer?.cancel();
    final query = rawQuery.trim();

    if (query.length < 2) {
      _autocompleteCancelToken?.cancel("Query too short");
      setState(() {
        _autocompleteData = null;
        _isLoadingAutocomplete = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchAutocomplete(query);
    });
  }

  Future<void> _fetchAutocomplete(String query) async {
    _autocompleteCancelToken?.cancel("New search typed");
    _autocompleteCancelToken = CancelToken();

    setState(() => _isLoadingAutocomplete = true);

    try {
      final response = await _productService.getAutocomplete(
        query: query,
        cancelToken: _autocompleteCancelToken,
      );

      if (!mounted) return;
      setState(() {
        _autocompleteData = response.data;
        _isLoadingAutocomplete = false;
      });
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() => _isLoadingAutocomplete = false);
    }
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    _searchController.text = query;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductListScreen(initialQuery: query)),
    );

    if (mounted) _loadHistory();
  }

  void _showError(Object e, String fallback) {
    final message = e is ApiException ? e.message : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeHistoryItem(SearchHistoryItem item) async {
    final index = _history.indexWhere((h) => h.id == item.id);
    if (index == -1) return;

    setState(() => _history.removeAt(index));

    try {
      await _productService.deleteSearchHistoryItem(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _history.insert(index.clamp(0, _history.length), item));
      _showError(e, 'Could not delete search');
    }
  }

  Future<void> _clearAllHistory() async {
    if (_isClearing || _history.isEmpty) return;

    final previous = List<SearchHistoryItem>.from(_history);
    setState(() {
      _history = [];
      _isClearing = true;
    });

    try {
      await _productService.clearSearchHistory();
      if (!mounted) return;
      setState(() => _isClearing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _history = previous;
        _isClearing = false;
      });
      _showError(e, 'Could not clear search history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;
    final isSearching = _searchController.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.onSurface, width: 2),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "Search",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: cs.onSurface, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: cs.onSurface),
                        cursorColor: cs.primary,
                        onChanged: (val) {
                          _onSearchChanged(val);
                          setState(() {});
                        },
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: "EXPLORE YOUR STYLE",
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: c.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                        child: Icon(Icons.clear, color: c.mutedText, size: 18),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: isSearching
                    ? _buildAutocompleteSection()
                    : _buildHistorySection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteSection() {
    final cs = context.cs;
    final c = context.appColors;

    if (_isLoadingAutocomplete) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    final queries = _autocompleteData?.queries ?? [];
    final instantProducts = _autocompleteData?.instantProducts ?? [];

    if (queries.isEmpty && instantProducts.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          "No suggestions found",
          style: TextStyle(fontSize: 14, color: c.mutedText),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (queries.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: queries.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
            itemBuilder: (context, index) {
              final queryText = queries[index];
              return InkWell(
                onTap: () => _search(queryText),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: c.mutedText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          queryText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.north_west, size: 14, color: c.mutedText),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        if (instantProducts.isNotEmpty) ...[
          Text(
            "Instant Results",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: instantProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = instantProducts[index];
                final imageUrl = product.thumbnail ?? product.imageUrl;

                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailsScreen(productId: product.id),
                    ),
                  ),
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 110,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: (imageUrl == null || imageUrl.isEmpty)
                              ? Container(color: cs.surfaceContainerHighest)
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: cs.surfaceContainerHighest,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${product.currency} ${product.price}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildHistorySection() {
    final cs = context.cs;
    final c = context.appColors;

    if (_isLoadingHistory) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_history.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          "No recent searches",
          style: TextStyle(fontSize: 14, color: c.mutedText),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Search",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            GestureDetector(
              onTap: _clearAllHistory,
              child: Text(
                "Clear All",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              return InkWell(
                onTap: () => _search(item.query),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20, color: cs.onSurface),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: cs.onSurface),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeHistoryItem(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
