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
import '../../widgets/load_more_button.dart';
import '../../widgets/product_grid_tile.dart';

/// F04 — Grille de produits filtrée par catégorie (`categ_id`). La
/// restriction aux produits vendables (`sale_ok = True`) est déjà imposée
/// côté serveur par l'`ir.rule` du module (voir CLAUDE.md § F03), pas
/// besoin de la dupliquer dans le domaine ici.
///
/// Pagination (demande utilisateur) : voir `utils/pagination.dart`.
class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String? categoryName;

  const CategoryProductsScreen({super.key, required this.categoryId, this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  final List<Map<String, dynamic>> _extraProducts = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Cf. home_screen.dart : détecte qu'une nouvelle page 1 a démarré
  // pendant l'appel réseau de _loadMore() (race condition trouvée à
  // l'audit technique du 2026-07-19).
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    context.read<FavoritesState>().refresh().catchError((_) {});
  }

  void _loadProducts() {
    _loadGeneration++;
    _extraProducts.clear();
    _offset = 0;
    _hasMore = true;
    setState(() {
      _productsFuture = _fetchProducts(offset: 0);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProducts({required int offset}) async {
    final api = context.read<OdooApiClient>();
    final categId = int.tryParse(widget.categoryId);
    final products = await api.searchRead(
      model: 'product.template',
      domain: categId != null
          ? [
              ['categ_id', '=', categId],
            ]
          : const [],
      fields: const ['name', 'list_price', 'image_128'],
      limit: kListPageSize,
      offset: offset,
    );
    _hasMore = products.length == kListPageSize;
    _offset = offset + products.length;
    // Disponibilité stock récupérée à part (contrôleur dédié, sudo() côté
    // serveur) plutôt que via le champ calculé qty_available exposé au
    // portail — voir status-V1.md § Points de vigilance.
    final ids = products.map((p) => p['id'] as int).toList();
    final stock = await api.getStock(productIds: ids);
    final promotions = await api.getPromotions(productIds: ids);
    for (final product in products) {
      final id = product['id'] as int;
      final qty = stock[id];
      if (qty != null) product['qty_available'] = qty;
      product['on_promo'] = promotions.containsKey(id);
      product['promo_percent'] = promotions[id];
    }
    return products;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchProducts(offset: _offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _extraProducts.addAll(more));
    } on AppError catch (e) {
      if (mounted && generation == _loadGeneration) AppMessenger.showError(context, e, onRetry: _loadMore);
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final favorites = context.watch<FavoritesState>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName ?? 'screens.CategoryProducts.title'.tr())),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _loadProducts);
            }
            final products = [...snapshot.data!, ..._extraProducts];
            if (products.isEmpty) {
              return const ErrorStateView(
                icon: Icons.storefront_outlined,
                titleKey: 'emptyStates.productsTitle',
                messageKey: 'emptyStates.productsMessage',
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
                        final product = products[index];
                        final productId = product['id'] as int;
                        return ProductGridTile(
                          product: product,
                          onTap: () => context.push('/catalog/product/$productId'),
                          cartQty: cart.quantityFor(productId),
                          onIncrement: () => addProductToCart(context, productId),
                          onDecrement: () => decrementCartProduct(context, productId),
                          isFavorite: favorites.isFavorite(productId),
                          onToggleFavorite: () => toggleFavorite(context, productId),
                        );
                      },
                      childCount: products.length,
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
