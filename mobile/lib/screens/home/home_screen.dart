import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';

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
              itemBuilder: (context, index) => _ProductCard(product: products[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final price = (product['list_price'] as num?)?.toDouble() ?? 0;
    final imageBase64 = product['image_128'];

    return InkWell(
      borderRadius: BorderRadius.circular(AppLayout.radius),
      onTap: () => context.push('/home/product/${product['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppLayout.radius),
              ),
              child: imageBase64 is String
                  ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                  : const Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${price.toStringAsFixed(2)} €',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
