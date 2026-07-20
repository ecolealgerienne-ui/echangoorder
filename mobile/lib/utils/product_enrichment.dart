import '../services/odoo_api_client.dart';

/// Enrichit une liste de produits (déjà chargée via `search_read`/un
/// contrôleur custom) avec la disponibilité stock (`qty_available`) et les
/// promotions actives (`on_promo`/`promo_percent`) — logique dupliquée à
/// l'identique dans 4 écrans (Accueil, Catalogue par catégorie, Recherche,
/// Favoris), trouvé à l'audit technique du 2026-07-19. Mutation des maps
/// en place (cohérent avec l'usage existant dans ces écrans), pas de
/// nouvelle liste renvoyée.
Future<void> enrichProductsWithStockAndPromotions(
  OdooApiClient api,
  List<Map<String, dynamic>> products,
) async {
  final ids = products.map((p) => p['id'] as int).toList();
  final stock = await api.getStock(productIds: ids);
  final promotions = await api.getPromotions(productIds: ids);
  for (final product in products) {
    final id = product['id'] as int;
    final qty = stock[id];
    if (qty != null) product['qty_available'] = qty;
    product['on_promo'] = promotions.containsKey(id);
    product['promo_percent'] = promotions[id];
  }
}
