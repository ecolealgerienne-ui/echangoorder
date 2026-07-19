import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/product_grid_tile.dart';

/// Liste de produits favoris : initialisée automatiquement à chaque
/// commande confirmée (produits achetés, dédupliqués côté serveur —
/// `controllers/checkout_controller.py._seed_favorites`), modifiable
/// ensuite par le client (retrait ici, ajout via l'écran de recherche
/// dédié ci-dessous). Aucun équivalent standard sans le module
/// `website_sale` (non installé) — modèle custom minimal
/// (`x_product_favorite`), voir CLAUDE.md.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Map<String, dynamic>>>? _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _favoritesFuture = context.read<OdooApiClient>().getFavorites();
    });
  }

  Future<void> _openAddScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _FavoritesAddScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _remove(Map<String, dynamic> product) async {
    try {
      await context.read<OdooApiClient>().removeFavorite(productId: product['id'] as int);
      if (!mounted) return;
      AppMessenger.showInfo(context, 'favorites.removed');
      _load();
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  final favorites = snapshot.data!;
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
                              : ListView.separated(
                                  itemCount: favorites.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (context, index) => _FavoriteTile(
                                    product: favorites[index],
                                    onTap: () => context.push('/profile/product/${favorites[index]['id']}'),
                                    onRemove: () => _remove(favorites[index]),
                                  ),
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

class _FavoriteTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteTile({required this.product, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final price = (product['list_price'] as num?)?.toDouble() ?? 0;
    final imageBase64 = product['image_128'];

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: imageBase64 is String
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppLayout.radius / 2),
                  child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover),
                )
              : const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
        ),
        title: Text(name),
        subtitle: Text('${price.toStringAsFixed(2)} €'),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: AppColors.danger),
          tooltip: 'common.delete'.tr(),
          onPressed: onRemove,
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

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _resultsFuture = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  void _search(String query) {
    setState(() {
      _resultsFuture = _fetchResults(query);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchResults(String query) {
    return context.read<OdooApiClient>().searchRead(
          model: 'product.template',
          domain: [
            ['name', 'ilike', query],
          ],
          fields: const ['name', 'list_price', 'image_128'],
          limit: 30,
        );
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
                  final results = snapshot.data!;
                  if (results.isEmpty) {
                    return const ErrorStateView(
                      icon: Icons.search_off,
                      titleKey: 'emptyStates.searchTitle',
                      messageKey: 'emptyStates.searchMessage',
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) => ProductGridTile(
                      product: results[index],
                      onTap: () => context.push('/profile/product/${results[index]['id']}'),
                      onAdd: () => _add(results[index]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
