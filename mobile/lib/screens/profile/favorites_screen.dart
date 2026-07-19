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
import '../../utils/toggle_favorite.dart';
import '../../widgets/app_button.dart';
import '../../widgets/load_more_button.dart';
import '../../widgets/product_grid_tile.dart';

/// Liste de produits favoris : initialisée automatiquement à chaque
/// commande confirmée (produits achetés, dédupliqués côté serveur —
/// `controllers/checkout_controller.py._seed_favorites`), modifiable
/// ensuite par le client (retrait ici, ajout via l'écran de recherche
/// dédié ci-dessous). Aucun équivalent standard sans le module
/// `website_sale` (non installé) — modèle custom minimal
/// (`x_product_favorite`), voir CLAUDE.md.
///
/// Même affichage que l'Accueil/Catalogue (`ProductGridTile` avec bouton
/// "Acheter" ↔ sélecteur de quantité) : cet écran sert avant tout à
/// recommander rapidement les produits habituels du client, pas juste à
/// les consulter. Le cœur (toujours plein ici) retire des favoris — la
/// tuile disparaît alors de la grille après un rechargement complet
/// (`_toggleFavorite`), plus simple qu'un filtrage local en direct.
///
/// Pagination (demande utilisateur) : voir `utils/pagination.dart`. Le
/// rechargement complet ci-dessus repart donc aussi de la 1re page.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Map<String, dynamic>>>? _favoritesFuture;
  final List<Map<String, dynamic>> _extraFavorites = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Cf. home_screen.dart : détecte qu'un rechargement complet a démarré
  // pendant l'appel réseau de _loadMore() (race condition trouvée à
  // l'audit technique du 2026-07-19).
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _loadGeneration++;
    _extraFavorites.clear();
    _offset = 0;
    _hasMore = true;
    setState(() {
      _favoritesFuture = _fetchFavorites(offset: 0);
    });
    context.read<FavoritesState>().refresh().catchError((_) {});
  }

  Future<List<Map<String, dynamic>>> _fetchFavorites({required int offset}) async {
    final api = context.read<OdooApiClient>();
    final favorites = await api.getFavorites(limit: kListPageSize, offset: offset);
    _hasMore = favorites.length == kListPageSize;
    _offset = offset + favorites.length;
    final ids = favorites.map((p) => p['id'] as int).toList();
    final stock = await api.getStock(productIds: ids);
    final promotions = await api.getPromotions(productIds: ids);
    for (final product in favorites) {
      final id = product['id'] as int;
      final qty = stock[id];
      if (qty != null) product['qty_available'] = qty;
      product['on_promo'] = promotions.containsKey(id);
      product['promo_percent'] = promotions[id];
    }
    return favorites;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchFavorites(offset: _offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _extraFavorites.addAll(more));
    } on AppError catch (e) {
      if (mounted && generation == _loadGeneration) AppMessenger.showError(context, e, onRetry: _loadMore);
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openAddScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _FavoritesAddScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _toggleFavorite(int productId) async {
    await toggleFavorite(context, productId);
    // Rechargement complet plutôt qu'un filtrage local en direct via
    // `FavoritesState` : évite un flash "aucun favori" pendant que son
    // premier chargement (asynchrone, indépendant de `_favoritesFuture`)
    // n'est pas encore arrivé.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    return Scaffold(
      appBar: AppBar(title: Text('screens.Favorites.title'.tr())),
      body: SafeArea(
        child: _favoritesFuture == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _favoritesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error is AppError
                        ? snapshot.error as AppError
                        : const AppError(AppError.unknown);
                    return ErrorStateView.forError(error, onRetry: _load);
                  }
                  final favorites = [...snapshot.data!, ..._extraFavorites];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: favorites.isEmpty
                              ? const ErrorStateView(
                                  icon: Icons.favorite_border,
                                  titleKey: 'emptyStates.favoritesTitle',
                                  messageKey: 'emptyStates.favoritesMessage',
                                )
                              : CustomScrollView(
                                  slivers: [
                                    SliverGrid(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: AppSpacing.md,
                                        crossAxisSpacing: AppSpacing.md,
                                        childAspectRatio: 0.62,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final product = favorites[index];
                                          final productId = product['id'] as int;
                                          return ProductGridTile(
                                            product: product,
                                            onTap: () => context.push('/profile/product/$productId'),
                                            cartQty: cart.quantityFor(productId),
                                            onIncrement: () => addProductToCart(context, productId),
                                            onDecrement: () => decrementCartProduct(context, productId),
                                            isFavorite: true,
                                            onToggleFavorite: () => _toggleFavorite(productId),
                                          );
                                        },
                                        childCount: favorites.length,
                                      ),
                                    ),
                                    if (_hasMore)
                                      SliverToBoxAdapter(
                                        child: LoadMoreButton(isLoading: _isLoadingMore, onPressed: _loadMore),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(label: 'favorites.addTitle'.tr(), onPressed: _openAddScreen),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Recherche + ajout de produits aux favoris (`name ilike`, même
/// anti-rebond que `SearchScreen` F04). Le "+" de `ProductGridTile` prend
/// ici le sens "ajouter aux favoris" plutôt que "ajouter au panier".
class _FavoritesAddScreen extends StatefulWidget {
  const _FavoritesAddScreen();

  @override
  State<_FavoritesAddScreen> createState() => _FavoritesAddScreenState();
}

class _FavoritesAddScreenState extends State<_FavoritesAddScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _resultsFuture;
  final List<Map<String, dynamic>> _extraResults = [];
  String _currentQuery = '';
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Cf. home_screen.dart / SearchScreen : détecte qu'une nouvelle
  // recherche a démarré pendant l'appel réseau de _loadMore() (race
  // condition trouvée à l'audit technique du 2026-07-19).
  int _loadGeneration = 0;

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
    final results = await context.read<OdooApiClient>().searchRead(
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

  Future<void> _add(Map<String, dynamic> product) async {
    try {
      await context.read<OdooApiClient>().addFavorite(productId: product['id'] as int);
      if (mounted) AppMessenger.showInfo(context, 'favorites.added');
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: '${'favorites.addTitle'.tr()}...',
            border: InputBorder.none,
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
                    return ErrorStateView.forError(error, onRetry: () => _search(_queryController.text.trim()));
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
                            (context, index) => ProductGridTile(
                              product: results[index],
                              onTap: () => context.push('/profile/product/${results[index]['id']}'),
                              onAdd: () => _add(results[index]),
                            ),
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
