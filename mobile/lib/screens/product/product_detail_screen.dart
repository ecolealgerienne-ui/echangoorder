import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/add_to_cart.dart';
import '../../utils/currency.dart';
import '../../widgets/app_button.dart';

/// F05 — Fiche produit : `product.template` par id (`read` standard, pas
/// de contrôleur custom). Disponibilité stock récupérée à part via
/// `OdooApiClient.getStock()` (contrôleur dédié en `sudo()`, voir F04).
class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _productFuture;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  void _loadProduct() {
    final id = int.tryParse(widget.productId);
    setState(() {
      _productFuture = id == null ? Future.error(const AppError(AppError.notFound)) : _fetchProduct(id);
    });
  }

  Future<Map<String, dynamic>> _fetchProduct(int id) async {
    final api = context.read<OdooApiClient>();
    final product = await api.read(
      model: 'product.template',
      id: id,
      fields: const ['name', 'description', 'list_price', 'image_1920', 'uom_id'],
    );
    final stock = await api.getStock(productIds: [id]);
    final qty = stock[id];
    if (qty != null) product['qty_available'] = qty;
    return product;
  }

  void _share() {
    // Lien placeholder — format et domaine réels à définir avec le choix de
    // techno deep link (Branch.io / Firebase Dynamic Links, cf. status-V1.md).
    final link = 'https://echanorder.app/produit/${widget.productId}';
    Share.share('${'share.intro'.tr()}\n$link');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Titre alimenté par le même Future que le corps de l'écran (pas
        // de titre du tout auparavant — oubli trouvé à l'audit technique
        // du 2026-07-19, contrairement à tous les autres écrans qui ont
        // au moins un titre statique). Vide pendant le chargement/en cas
        // d'erreur plutôt que de dupliquer la gestion d'erreur ici, déjà
        // affichée dans le corps.
        title: FutureBuilder<Map<String, dynamic>>(
          future: _productFuture,
          builder: (context, snapshot) => Text(snapshot.data?['name'] as String? ?? ''),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share), onPressed: _share),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _productFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _loadProduct);
            }

            final product = snapshot.data!;
            final name = product['name'] as String? ?? '';
            final price = (product['list_price'] as num?)?.toDouble() ?? 0;
            final imageBase64 = product['image_1920'];
            final descriptionRaw = product['description'];
            final description = descriptionRaw is String ? _stripHtml(descriptionRaw) : '';
            final uomField = product['uom_id'];
            final uomName = uomField is List && uomField.length > 1 ? uomField[1] as String : '';
            final qtyAvailable = (product['qty_available'] as num?)?.toDouble();
            final outOfStock = qtyAvailable != null && qtyAvailable <= 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppLayout.radius),
                      ),
                      child: imageBase64 is String
                          ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported_outlined, size: 64, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    uomName.isEmpty
                        ? formatPrice(context, price)
                        : '${formatPrice(context, price)} / $uomName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text('$_quantity', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _quantity++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (outOfStock) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'errors.checkout.out_of_stock'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'actions.addToCart'.tr(),
                    onPressed: outOfStock
                        ? null
                        : () => addProductToCart(context, product['id'] as int, qty: _quantity),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// `description` est un champ Html côté Odoo — pas de rendu riche ici
/// (éviterait d'ajouter une dépendance juste pour ça) : on retire les
/// balises et on affiche le texte brut.
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
