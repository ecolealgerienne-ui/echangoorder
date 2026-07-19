import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/add_to_cart.dart';
import '../../widgets/product_grid_tile.dart';

/// F04 — Grille de produits filtrée par catégorie (`categ_id`). La
/// restriction aux produits vendables (`sale_ok = True`) est déjà imposée
/// côté serveur par l'`ir.rule` du module (voir CLAUDE.md § F03), pas
/// besoin de la dupliquer dans le domaine ici.
class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String? categoryName;

  const CategoryProductsScreen({super.key, required this.categoryId, this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final api = context.read<OdooApiClient>();
    final categId = int.tryParse(widget.categoryId);
    setState(() {
      _productsFuture = api.searchRead(
        model: 'product.template',
        domain: categId != null
            ? [
                ['categ_id', '=', categId],
              ]
            : const [],
        // Pas de qty_available : champ calculé qui lit product.product PUIS
        // stock.warehouse (et probablement plus loin) — trop de surface
        // interne à ouvrir au portail pour ce que ça apporte ici. Le badge
        // "épuisé" restera inactif tant qu'on n'a pas un signal de stock
        // plus étroit (voir status-V1.md).
        fields: const ['name', 'list_price', 'image_128'],
        limit: 50,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
            final products = snapshot.data!;
            if (products.isEmpty) {
              return const ErrorStateView(
                icon: Icons.storefront_outlined,
                titleKey: 'emptyStates.productsTitle',
                messageKey: 'emptyStates.productsMessage',
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
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductGridTile(
                  product: product,
                  onTap: () => context.push('/catalog/product/${product['id']}'),
                  onAdd: () => addProductToCart(context, product['id'] as int),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
