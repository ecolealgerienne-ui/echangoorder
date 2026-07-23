import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../errors/app_error.dart';
import '../errors/app_messenger.dart';
import '../state/cart_state.dart';
import 'require_account.dart';

/// Ajoute un produit au panier (F06), après vérification du compte
/// (invité → proposition d'inscription, cf. [requireAccount]). Centralise
/// la gestion d'erreur commune aux écrans qui déclenchent un ajout (fiche
/// produit, catalogue par catégorie, recherche) pour éviter de dupliquer
/// le même try/catch trois fois.
Future<void> addProductToCart(BuildContext context, int productId, {num qty = 1, int? variantId}) async {
  if (!await requireAccount(context)) return;
  if (!context.mounted) return;
  try {
    await context.read<CartState>().add(productId: productId, qty: qty, variantId: variantId);
  } on AppError catch (error) {
    if (context.mounted) {
      AppMessenger.showError(
        context,
        error,
        onRetry: () => addProductToCart(context, productId, qty: qty, variantId: variantId),
      );
    }
  }
}

/// Ajout rapide depuis une grille produit (Accueil/Recherche/Favoris,
/// bouton "Acheter"/`+`) : un produit qui a plusieurs variantes
/// (couleur/taille...) ne peut pas être ajouté à l'aveugle avec la
/// variante par défaut — signalé par l'utilisateur, l'ajout rapide ne
/// proposait jamais le choix, contrairement à la fiche produit (F05).
/// `product_variant_count` (champ standard Odoo, > 1 s'il y a au moins un
/// attribut avec plusieurs valeurs à combiner) permet de le détecter sans
/// charger `attribute_line_ids` juste pour cette vérification. Redirige
/// vers la fiche produit (où le sélecteur de variante existe déjà) plutôt
/// que de dupliquer ce sélecteur dans un dialogue de la grille — reste un
/// ajout direct, inchangé, pour l'immense majorité des produits sans
/// variante.
Future<void> addProductOrOpenDetail(
  BuildContext context,
  Map<String, dynamic> product,
  String detailRoute,
) async {
  final variantCount = (product['product_variant_count'] as num?)?.toInt() ?? 1;
  if (variantCount > 1) {
    // `extra: product` (2026-07-21, demande utilisateur) : la grille a déjà
    // nom/prix/image/stock, transmis pour un affichage instantané de la
    // fiche produit — voir `ProductDetailScreen.initialData`.
    context.push(detailRoute, extra: product);
    return;
  }
  await addProductToCart(context, product['id'] as int);
}

/// Diminue d'une unité la quantité déjà au panier pour ce produit (sans
/// [requireAccount] : le sélecteur de quantité qui déclenche ceci n'est
/// affiché que pour un produit déjà présent au panier, donc déjà pour un
/// compte réel).
Future<void> decrementCartProduct(BuildContext context, int productId) async {
  try {
    await context.read<CartState>().decrementProduct(productId);
  } on AppError catch (error) {
    if (context.mounted) {
      AppMessenger.showError(context, error, onRetry: () => decrementCartProduct(context, productId));
    }
  }
}
