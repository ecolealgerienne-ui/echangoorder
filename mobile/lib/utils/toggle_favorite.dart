import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../errors/app_error.dart';
import '../errors/app_messenger.dart';
import '../state/favorites_state.dart';
import 'require_account.dart';

/// Bascule un produit dans/hors des favoris (cœur sur `ProductGridTile`),
/// après vérification du compte (invité → proposition d'inscription,
/// cf. [requireAccount]) — mêmes règles que l'ajout au panier.
Future<void> toggleFavorite(BuildContext context, int productId) async {
  if (!await requireAccount(context)) return;
  if (!context.mounted) return;
  final favorites = context.read<FavoritesState>();
  try {
    if (favorites.isFavorite(productId)) {
      await favorites.remove(productId);
    } else {
      await favorites.add(productId);
    }
  } on AppError catch (error) {
    if (context.mounted) AppMessenger.showError(context, error);
  }
}
