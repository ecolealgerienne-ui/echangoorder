import 'package:flutter/foundation.dart';
import '../services/odoo_api_client.dart';

/// Ensemble des ids (`product.template`) marqués favoris par le client
/// connecté — reflète `x_product_favorite` côté Odoo (voir
/// `controllers/favorites_controller.py`). Rechargé à chaque visite d'un
/// écran de catalogue (Accueil/Catalogue/Recherche) comme le stock, puis
/// mis à jour localement à chaque bascule (pas de round-trip complet).
class FavoritesState extends ChangeNotifier {
  FavoritesState(this._api);

  final OdooApiClient _api;
  Set<int> _ids = {};

  bool isFavorite(int productId) => _ids.contains(productId);

  Future<void> refresh() async {
    final favorites = await _api.getFavorites();
    _ids = favorites.map((p) => p['id'] as int).toSet();
    notifyListeners();
  }

  Future<void> add(int productId) async {
    await _api.addFavorite(productId: productId);
    _ids.add(productId);
    notifyListeners();
  }

  Future<void> remove(int productId) async {
    await _api.removeFavorite(productId: productId);
    _ids.remove(productId);
    notifyListeners();
  }
}
