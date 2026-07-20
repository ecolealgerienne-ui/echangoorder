import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  // attribute_id -> id du `product.template.attribute.value` choisi (F05,
  // couleur/taille...) — pré-rempli avec la première valeur de chaque
  // attribut au chargement (voir _fetchProduct), ajustable ensuite via les
  // chips de sélection.
  final Map<int, int> _selectedValues = {};

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
    // Produits de substitution (décision produit 2026-07) — curation
    // manuelle admin (`x_substitute_product_ids`), affichés ici pour que le
    // client les découvre en amont, pas seulement au checkout en cas de
    // rupture (voir CheckoutResolveUnavailableScreen).
    product['substitutes'] = await api.getSubstitutes(productId: id);
    // Variantes (F05, couleur/taille...) — mécanisme standard Odoo
    // jusqu'ici ignoré par l'app, qui n'ajoutait toujours que la variante
    // par défaut. `attributes` vide = produit sans variante (immense
    // majorité du catalogue), aucune UI supplémentaire dans ce cas.
    final variantsData = await api.getVariants(productId: id);
    final attributes = (variantsData['attributes'] as List).cast<Map<String, dynamic>>();
    product['attributes'] = attributes;
    product['variants'] = variantsData['variants'];
    if (_selectedValues.isEmpty) {
      for (final attr in attributes) {
        final values = (attr['values'] as List).cast<Map<String, dynamic>>();
        if (values.isNotEmpty) {
          _selectedValues[attr['attribute_id'] as int] = values.first['id'] as int;
        }
      }
    }
    return product;
  }

  /// Trouve la variante dont la combinaison d'attributs correspond
  /// exactement à la sélection en cours — `null` tant que la sélection est
  /// incomplète (jamais le cas en pratique ici, chaque attribut est
  /// pré-rempli au chargement) ou si la combinaison n'existe pas (valeurs
  /// exclues entre elles, cas avancé non géré).
  Map<String, dynamic>? _resolveVariant(List<Map<String, dynamic>> attributes, List<Map<String, dynamic>> variants) {
    if (attributes.isEmpty) return null;
    if (_selectedValues.length != attributes.length) return null;
    final chosen = _selectedValues.values.toSet();
    for (final variant in variants) {
      final ids = (variant['attribute_value_ids'] as List).cast<int>().toSet();
      if (ids.length == chosen.length && ids.containsAll(chosen)) return variant;
    }
    return null;
  }

  /// Les 3 branches (Accueil/Catalogue/Profil) exposent chacune leur propre
  /// route `product/:productId` (voir app_router.dart) — cet écran ne sait
  /// pas statiquement sous laquelle il est monté. `matchedLocation` donne
  /// le chemin complet (ex. `/catalog/product/42`) : on en déduit le
  /// préfixe de branche pour pousser un autre produit sur la même pile,
  /// plutôt que de coder en dur une seule branche.
  void _openProduct(int productId) {
    final location = GoRouterState.of(context).matchedLocation;
    final branch = location.split('/product/').first;
    context.push('$branch/product/$productId');
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
            final imageBase64 = product['image_1920'];
            final descriptionRaw = product['description'];
            final description = descriptionRaw is String ? _stripHtml(descriptionRaw) : '';
            final uomField = product['uom_id'];
            final uomName = uomField is List && uomField.length > 1 ? uomField[1] as String : '';
            final substitutes = (product['substitutes'] as List? ?? const []).cast<Map<String, dynamic>>();
            final attributes = (product['attributes'] as List? ?? const []).cast<Map<String, dynamic>>();
            final variants = (product['variants'] as List? ?? const []).cast<Map<String, dynamic>>();
            final hasVariants = attributes.isNotEmpty;
            final resolvedVariant = hasVariants ? _resolveVariant(attributes, variants) : null;
            // Prix/stock de la variante résolue une fois la combinaison
            // complète (toujours le cas ici, chaque attribut pré-rempli au
            // chargement) — repli sur le prix/stock du template pour un
            // produit sans variante, comportement inchangé dans ce cas.
            final price = hasVariants
                ? (resolvedVariant?['list_price'] as num?)?.toDouble() ?? 0
                : (product['list_price'] as num?)?.toDouble() ?? 0;
            final qtyAvailable = hasVariants
                ? (resolvedVariant?['qty_available'] as num?)?.toDouble()
                : (product['qty_available'] as num?)?.toDouble();
            final outOfStock = (hasVariants && resolvedVariant == null) ||
                (qtyAvailable != null && qtyAvailable <= 0);

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
                  if (hasVariants) ...[
                    const SizedBox(height: AppSpacing.lg),
                    for (final attribute in attributes)
                      _AttributeSelector(
                        attribute: attribute,
                        selectedValueId: _selectedValues[attribute['attribute_id'] as int],
                        onSelect: (valueId) =>
                            setState(() => _selectedValues[attribute['attribute_id'] as int] = valueId),
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
                        : () => addProductToCart(
                              context,
                              product['id'] as int,
                              qty: _quantity,
                              variantId: resolvedVariant?['id'] as int?,
                            ),
                  ),
                  if (substitutes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('product.substitutesTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: substitutes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) => _SubstituteTile(
                          substitute: substitutes[index],
                          onTap: () => _openProduct(substitutes[index]['id'] as int),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// F05 — sélecteur d'une valeur d'attribut (couleur/taille...) sous forme
/// de puces (`ChoiceChip`), une rangée par attribut. Chaque valeur est un
/// `product.template.attribute.value` (voir `catalog_controller.py.
/// variants()`) — son id est ce qui est comparé côté app pour résoudre la
/// variante exacte, pas le nom affiché.
class _AttributeSelector extends StatelessWidget {
  final Map<String, dynamic> attribute;
  final int? selectedValueId;
  final ValueChanged<int> onSelect;

  const _AttributeSelector({required this.attribute, required this.selectedValueId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final values = (attribute['values'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(attribute['name'] as String? ?? '', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(value['name'] as String? ?? ''),
                  selected: value['id'] == selectedValueId,
                  onSelected: (_) => onSelect(value['id'] as int),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubstituteTile extends StatelessWidget {
  final Map<String, dynamic> substitute;
  final VoidCallback onTap;

  const _SubstituteTile({required this.substitute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageBase64 = substitute['image_128'];
    final qtyAvailable = (substitute['qty_available'] as num?)?.toDouble();
    final outOfStock = qtyAvailable != null && qtyAvailable <= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(AppLayout.radius),
      onTap: onTap,
      child: SizedBox(
        width: 84,
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
                    ? Opacity(
                        opacity: outOfStock ? 0.4 : 1,
                        child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover),
                      )
                    : const Icon(Icons.image_not_supported_outlined, size: 28, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              substitute['name'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
