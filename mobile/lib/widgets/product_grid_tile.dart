import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tuile produit réutilisée par l'Accueil (F03), le Catalogue/Recherche
/// (F04) et l'écran d'ajout de favoris.
///
/// Deux modes d'ajout mutuellement exclusifs :
/// - [onAdd] : bouton "+" simple (utilisé par l'écran d'ajout de favoris,
///   où "+" signifie "ajouter aux favoris", pas de notion de quantité).
/// - [cartQty] + [onIncrement]/[onDecrement] : bouton "Acheter" tant que
///   le produit n'est pas au panier, puis sélecteur de quantité (− qty +)
///   une fois ajouté (Accueil/Catalogue/Recherche) — repris du wireframe
///   fourni par l'utilisateur.
///
/// [isFavorite]/[onToggleFavorite] ajoutent un cœur en superposition sur
/// l'image (Accueil/Catalogue/Recherche uniquement, absent de l'écran
/// d'ajout de favoris où ce serait redondant avec le "+").
///
/// Le badge "Promo" lit `product['on_promo']` (bool) et `promo_percent`
/// (num?, absent/null si la remise n'est pas exprimée en %), fusionnés par
/// l'écran appelant comme `qty_available` — voir
/// `OdooApiClient.getPromotions`, module standard `loyalty` ; masqué si le
/// produit est épuisé, couleur dédiée (`AppColors.promo`) pour le
/// distinguer du bouton "Acheter" (vert) et du badge "Épuisé" (rouge).
class ProductGridTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final num? cartQty;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const ProductGridTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.cartQty,
    this.onIncrement,
    this.onDecrement,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final price = (product['list_price'] as num?)?.toDouble() ?? 0;
    final qty = (product['qty_available'] as num?)?.toDouble();
    final outOfStock = qty != null && qty <= 0;
    final onPromo = product['on_promo'] as bool? ?? false;
    final promoPercent = (product['promo_percent'] as num?)?.toDouble();
    final imageBase64 = product['image_128'];

    return InkWell(
      borderRadius: BorderRadius.circular(AppLayout.radius),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
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
                      : const Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textMuted),
                ),
                if (outOfStock)
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppLayout.radius / 2),
                      ),
                      child: Text(
                        'catalog.outOfStock'.tr(),
                        style: const TextStyle(color: AppColors.background, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                // Épuisé prime sur promo — pas de sens à mettre en avant
                // une réduction sur un produit qu'on ne peut pas acheter.
                else if (onPromo)
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.promo,
                        borderRadius: BorderRadius.circular(AppLayout.radius / 2),
                      ),
                      child: Text(
                        promoPercent != null
                            ? 'catalog.onPromoPercent'.tr(namedArgs: {'percent': promoPercent.toStringAsFixed(0)})
                            : 'catalog.onPromo'.tr(),
                        style: const TextStyle(color: AppColors.background, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onToggleFavorite != null)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: _FavoriteButton(isFavorite: isFavorite, onPressed: onToggleFavorite!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          Text('${price.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.bodySmall),
          if (cartQty != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _CartQuantityControl(
              qty: cartQty!,
              outOfStock: outOfStock,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            ),
          ] else if (onAdd != null)
            Align(
              alignment: Alignment.centerRight,
              // Pas de padding/constraints custom : on garde la zone de
              // tap par défaut d'IconButton (>= 44px, cf. CLAUDE.md §
              // Accessibilité) plutôt que de la resserrer visuellement.
              child: IconButton(
                onPressed: outOfStock ? null : onAdd,
                icon: Icon(
                  Icons.add_circle,
                  color: outOfStock ? AppColors.disabled : AppColors.primary,
                ),
                tooltip: 'actions.addToCart'.tr(),
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onPressed;

  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppColors.danger : AppColors.textMuted,
        ),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CartQuantityControl extends StatelessWidget {
  final num qty;
  final bool outOfStock;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _CartQuantityControl({
    required this.qty,
    required this.outOfStock,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    if (qty <= 0) {
      return SizedBox(
        width: double.infinity,
        height: AppLayout.minTouchHeight,
        child: ElevatedButton.icon(
          onPressed: outOfStock ? null : onIncrement,
          icon: const Icon(Icons.add, size: 18),
          label: Text('actions.buy'.tr()),
          style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
        ),
      );
    }
    return SizedBox(
      height: AppLayout.minTouchHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
          Text('$qty', style: Theme.of(context).textTheme.bodyMedium),
          IconButton(
            onPressed: outOfStock ? null : onIncrement,
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
