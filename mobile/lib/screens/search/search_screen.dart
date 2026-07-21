import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../state/cart_state.dart';
import '../../state/favorites_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/add_to_cart.dart';
import '../../utils/pagination.dart';
import '../../utils/product_enrichment.dart';
import '../../utils/toggle_favorite.dart';
import '../../widgets/load_more_button.dart';
import '../../widgets/product_grid_tile.dart';

/// F04 — Recherche par nom (`name ilike`), avec un léger anti-rebond pour
/// éviter un appel réseau à chaque frappe.
///
/// Pagination (demande utilisateur) : voir `utils/pagination.dart` —
/// réinitialisée à chaque nouvelle recherche.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _resultsFuture;
  final List<Map<String, dynamic>> _extraResults = [];
  String _currentQuery = '';
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Cf. home_screen.dart : détecte qu'une nouvelle recherche a démarré
  // pendant l'appel réseau de _loadMore() (race condition trouvée à
  // l'audit technique du 2026-07-19 — cas explicitement cité : taper une
  // nouvelle recherche juste après avoir appuyé sur "Charger plus").
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    context.read<FavoritesState>().refresh().catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _loadGeneration++;
      setState(() => _resultsFuture = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  void _search(String query) {
    _loadGeneration++;
    _currentQuery = query;
    _extraResults.clear();
    _offset = 0;
    _hasMore = true;
    setState(() {
      _resultsFuture = _fetchResults(query, offset: 0);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchResults(String query, {required int offset}) async {
    final api = context.read<OdooApiClient>();
    final results = await api.searchRead(
      model: 'product.template',
      domain: [
        ['name', 'ilike', query],
      ],
      fields: const ['name', 'list_price', 'image_128'],
      limit: kListPageSize,
      offset: offset,
    );
    _hasMore = results.length == kListPageSize;
    _offset = offset + results.length;
    // Disponibilité stock + promotions à part — même logique que HomeScreen.
    await enrichProductsWithStockAndPromotions(api, results);
    return results;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchResults(_currentQuery, offset: _offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _extraResults.addAll(more));
    } on AppError catch (e) {
      if (mounted && generation == _loadGeneration) AppMessenger.showError(context, e, onRetry: _loadMore);
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _isLoadingMore = false);
    }
  }

  void _clear() {
    _debounce?.cancel();
    _loadGeneration++;
    _queryController.clear();
    setState(() => _resultsFuture = null);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final favorites = context.watch<FavoritesState>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: '${'screens.Search.title'.tr()}...',
            border: InputBorder.none,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _queryController,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(icon: const Icon(Icons.close), onPressed: _clear),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _resultsFuture == null
            ? const ErrorStateView(
                icon: Icons.search_off,
                titleKey: 'emptyStates.searchTitle',
                messageKey: 'emptyStates.searchMessage',
              )
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _resultsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error is AppError
                        ? snapshot.error as AppError
                        : const AppError(AppError.unknown);
                    return ErrorStateView.forError(
                      error,
                      onRetry: () => _search(_queryController.text.trim()),
                    );
                  }
                  final results = [...snapshot.data!, ..._extraResults];
                  if (results.isEmpty) {
                    return const ErrorStateView(
                      icon: Icons.search_off,
                      titleKey: 'emptyStates.searchTitle',
                      messageKey: 'emptyStates.searchMessage',
                    );
                  }
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.62,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = results[index];
                              final productId = product['id'] as int;
                              return ProductGridTile(
                                product: product,
                                onTap: () => context.push('/home/product/$productId'),
                                cartQty: cart.quantityFor(productId),
                                onIncrement: () =>
                                    addProductOrOpenDetail(context, product, '/home/product/$productId'),
                                onDecrement: () => decrementCartProduct(context, productId),
                                isFavorite: favorites.isFavorite(productId),
                                onToggleFavorite: () => toggleFavorite(context, productId),
                              );
                            },
                            childCount: results.length,
                          ),
                        ),
                      ),
                      if (_hasMore)
                        SliverToBoxAdapter(
                          child: LoadMoreButton(isLoading: _isLoadingMore, onPressed: _loadMore),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
