import 'package:flutter/material.dart';
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
Future<void> addProductToCart(BuildContext context, int productId, {num qty = 1}) async {
  if (!await requireAccount(context)) return;
  if (!context.mounted) return;
  try {
    await context.read<CartState>().add(productId: productId, qty: qty);
  } on AppError catch (error) {
    if (context.mounted) {
      AppMessenger.showError(
        context,
        error,
        onRetry: () => addProductToCart(context, productId, qty: qty),
      );
    }
  }
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
