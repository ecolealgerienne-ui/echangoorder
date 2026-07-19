import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../state/cart_state.dart';
import '../../state/favorites_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/add_to_cart.dart';
import '../../utils/toggle_favorite.dart';
import '../../widgets/product_grid_tile.dart';

/// F04 — Recherche par nom (`name ilike`), avec un léger anti-rebond pour
/// éviter un appel réseau à chaque frappe.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _resultsFuture;

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

  Future<List<Map<String, dynamic>>> _fetchResults(String query) async {
    final api = context.read<OdooApiClient>();
    final results = await api.searchRead(
      model: 'product.template',
      domain: [
        ['name', 'ilike', query],
      ],
      fields: const ['name', 'list_price', 'image_128'],
      limit: 30,
    );
    // Disponibilité stock à part — voir CategoryProductsScreen.
    final stock = await api.getStock(productIds: results.map((p) => p['id'] as int).toList());
    for (final product in results) {
      final qty = stock[product['id'] as int];
      if (qty != null) product['qty_available'] = qty;
    }
    return results;
  }

  void _clear() {
    _debounce?.cancel();
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
                    itemBuilder: (context, index) {
                      final product = results[index];
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
                  );
                },
              ),
      ),
    );
  }
}
