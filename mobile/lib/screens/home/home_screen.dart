import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_grid_tile.dart';

/// F03 — Accueil : grille des produits vendables (`product.template`,
/// `sale_ok = true`) via le `search_read` standard d'Odoo. La curation
/// "produits mis en avant" (spec Expert Odoo : `is_published`, un champ
/// qui n'existe pas sans le module website_sale) n'est pas encore
/// implémentée — voir CLAUDE.md § Custom fields (`x_vitrine_publique`)
/// pour la piste envisagée quand F00 sera traité.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final api = context.read<OdooApiClient>();
    setState(() {
      _productsFuture = api.searchRead(
        model: 'product.template',
        domain: const [
          ['sale_ok', '=', true],
        ],
        fields: const ['name', 'list_price', 'image_128'],
        limit: 20,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.Home.title'.tr())),
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
                childAspectRatio: 0.72,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductGridTile(
                  product: product,
                  onTap: () => context.push('/home/product/${product['id']}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
