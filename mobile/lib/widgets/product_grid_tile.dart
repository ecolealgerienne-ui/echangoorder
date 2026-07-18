import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tuile produit réutilisée par l'Accueil (F03) et le Catalogue/Recherche
/// (F04) : photo, nom, prix. [onAdd] est optionnel — l'Accueil n'a pas de
/// bouton d'ajout rapide dans son wireframe, le Catalogue/Recherche oui.
/// Pas de vrai ajout au panier tant que F06 n'existe pas : le contenu
/// d'[onAdd] (souvent `showComingSoon`) reste au choix de l'écran appelant.
class ProductGridTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const ProductGridTile({super.key, required this.product, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final price = (product['list_price'] as num?)?.toDouble() ?? 0;
    final qty = (product['qty_available'] as num?)?.toDouble();
    final outOfStock = qty != null && qty <= 0;
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
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${price.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.bodySmall),
              if (onAdd != null)
                // Pas de padding/constraints custom : on garde la zone de
                // tap par défaut d'IconButton (>= 44px, cf. CLAUDE.md §
                // Accessibilité) plutôt que de la resserrer visuellement.
                IconButton(
                  onPressed: outOfStock ? null : onAdd,
                  icon: Icon(
                    Icons.add_circle,
                    color: outOfStock ? AppColors.disabled : AppColors.primary,
                  ),
                  tooltip: 'actions.addToCart'.tr(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
