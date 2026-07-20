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
import '../../widgets/shimmer_loader.dart';

/// F03 — Accueil : grille des produits vendables (`product.template`,
/// `sale_ok = true`) via le `search_read` standard d'Odoo. La curation
/// "produits mis en avant" (spec Expert Odoo : `is_published`, un champ
/// qui n'existe pas sans le module website_sale) n'est pas encore
/// implémentée — voir CLAUDE.md § Custom fields (`x_vitrine_publique`)
/// pour la piste envisagée quand F00 sera traité.
///
/// Pagination (demande utilisateur) : `kListPageSize` produits par page,
/// chargement à la demande via `LoadMoreButton` plutôt que tout afficher
/// d'un coup — voir `utils/pagination.dart`.
///
/// Bandeau recherche + catégories (direction Casbah, phase C) : accès
/// direct depuis l'Accueil plutôt que de forcer un détour par l'onglet
/// Catalogue. Navigue vers les écrans F04 existants (`/catalog/search`,
/// `/catalog/category/:id`) plutôt que de dupliquer leur logique de
/// recherche/filtrage ici — l'Accueil reste une simple vitrine d'entrée.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  final List<Map<String, dynamic>> _extraProducts = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Incrémenté à chaque _loadProducts() (init, tirer-pour-rafraîchir) :
  // permet à _loadMore() de détecter qu'une nouvelle page 1 a démarré
  // pendant son propre appel réseau et d'ignorer son résultat devenu
  // obsolète, plutôt que de mélanger les deux listes (race condition
  // trouvée à l'audit technique du 2026-07-19).
  int _loadGeneration = 0;

  // Bandeau catégories : purement décoratif/navigation, jamais bloquant —
  // masqué silencieusement en cas d'échec plutôt que de gêner l'accès à la
  // grille produits (qui reste l'essentiel de l'écran).
  Future<List<Map<String, dynamic>>>? _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
    // Non bloquant et silencieux : un échec (invité sans session Odoo,
    // réseau...) ne doit pas empêcher de parcourir l'Accueil, les cœurs
    // restent juste tous "non favoris" dans ce cas.
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

  void _loadCategories() {
    setState(() {
      _categoriesFuture = context.read<OdooApiClient>().readGroup(
        model: 'product.template',
        domain: const [
          ['sale_ok', '=', true],
        ],
        groupBy: const ['categ_id'],
      );
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProducts({required int offset}) async {
    final api = context.read<OdooApiClient>();
    final products = await api.searchRead(
      model: 'product.template',
      domain: const [
        ['sale_ok', '=', true],
      ],
      fields: const ['name', 'list_price', 'image_128'],
      limit: kListPageSize,
      offset: offset,
    );
    _hasMore = products.length == kListPageSize;
    _offset = offset + products.length;
    // Disponibilité stock + promotions récupérées à part (contrôleurs
    // dédiés, sudo() côté serveur) — même logique que Catalogue/Recherche
    // (F04), manquait ici.
    await enrichProductsWithStockAndPromotions(api, products);
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

  Future<void> _handleRefresh() async {
    _loadProducts();
    _loadCategories();
    try {
      await _productsFuture;
    } catch (_) {
      // Déjà affiché par le FutureBuilder (snapshot.hasError).
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final favorites = context.watch<FavoritesState>();

    return Scaffold(
      appBar: AppBar(title: Text('screens.Home.title'.tr())),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _SearchBar(onTap: () => context.push('/catalog/search'))),
                    SliverToBoxAdapter(child: _buildCategoryChips(context)),
                    const SliverPadding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      sliver: _ProductGridSkeleton(),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                final error =
                    snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
                return ErrorStateView.forError(error, onRetry: _loadProducts);
              }
              final products = [...snapshot.data!, ..._extraProducts];
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _SearchBar(onTap: () => context.push('/catalog/search'))),
                  SliverToBoxAdapter(child: _buildCategoryChips(context)),
                  if (products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorStateView(
                        icon: Icons.storefront_outlined,
                        titleKey: 'emptyStates.productsTitle',
                        messageKey: 'emptyStates.productsMessage',
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
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
                              onTap: () => context.push('/home/product/$productId'),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _CategoryChipsSkeleton();
        }
        // Décoratif uniquement : une erreur ou une liste vide ne doit rien
        // afficher plutôt que de perturber l'accès à la grille produits.
        if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        final groups = snapshot.data!;
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // +1 : puce "Tous" en tête, représente la grille déjà affichée
            // (sélectionnée, non interactive) plutôt qu'une vraie catégorie.
            itemCount: groups.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ChoiceChip(
                  label: Text('catalog.allCategories'.tr()),
                  selected: true,
                  onSelected: (_) {},
                );
              }
              final categField = groups[index - 1]['categ_id'] as List<dynamic>?;
              if (categField == null) return const SizedBox.shrink();
              final categId = categField[0] as int;
              final categName = categField[1] as String;
              return ChoiceChip(
                label: Text(categName),
                selected: false,
                onSelected: (_) => context.push('/catalog/category/$categId', extra: categName),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayout.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('${'screens.Search.title'.tr()}...', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChipsSkeleton extends StatelessWidget {
  const _CategoryChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => ShimmerBox(
          width: 72,
          height: 32,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.62,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ShimmerBox(width: double.infinity, height: double.infinity)),
            const SizedBox(height: AppSpacing.xs),
            const ShimmerBox(width: double.infinity, height: 14),
            const SizedBox(height: AppSpacing.xs),
            ShimmerBox(width: 60, height: 12, borderRadius: BorderRadius.circular(4)),
          ],
        ),
        childCount: 6,
      ),
    );
  }
}
