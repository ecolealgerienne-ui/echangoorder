import '../services/odoo_api_client.dart';

/// Enrichit une liste de produits (déjà chargée via `search_read`/un
/// contrôleur custom) avec la disponibilité stock (`qty_available`), le
/// nombre de variantes (`product_variant_count`, F05 — permet à
/// `addProductOrOpenDetail` de savoir s'il faut rediriger vers la fiche
/// produit) et les promotions actives (`on_promo`/`promo_percent`) —
/// logique dupliquée à l'identique dans plusieurs écrans (Accueil,
/// Recherche, Favoris), trouvé à l'audit technique du 2026-07-19. Mutation
/// des maps en place (cohérent avec l'usage existant dans ces écrans), pas
/// de nouvelle liste renvoyée.
Future<void> enrichProductsWithStockAndPromotions(
  OdooApiClient api,
  List<Map<String, dynamic>> products,
) async {
  final ids = products.map((p) => p['id'] as int).toList();
  // Les deux appels sont indépendants (endpoints distincts, aucune donnée
  // de l'un ne dépend de l'autre) — lancés en parallèle plutôt qu'attendus
  // l'un après l'autre (audit performance signalé par l'utilisateur,
  // 2026-07-21) : sur un backend Odoo local en un seul worker (WSL/Docker,
  // voir status-V1.md), ça ne change rien côté serveur (une requête à la
  // fois de toute façon), mais ça évite d'ajouter l'aller-retour réseau
  // (latence WSL2) du second appel après la fin complète du premier.
  final stockFuture = api.getStock(productIds: ids);
  final promotionsFuture = api.getPromotions(productIds: ids);
  final stock = await stockFuture;
  final promotions = await promotionsFuture;
  for (final product in products) {
    final id = product['id'] as int;
    final qty = stock.stock[id];
    if (qty != null) product['qty_available'] = qty;
    product['product_variant_count'] = stock.variantCounts[id] ?? 1;
    product['on_promo'] = promotions.containsKey(id);
    product['promo_percent'] = promotions[id];
  }
}
