import 'package:flutter/foundation.dart';
import '../services/odoo_api_client.dart';

class CartLine {
  final int lineId;
  final int productId;
  final String name;
  final String? imageBase64;
  final String? uom;
  final num qty;
  final double unitPrice;
  final double subtotal;

  const CartLine({
    required this.lineId,
    required this.productId,
    required this.name,
    required this.imageBase64,
    required this.uom,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
  });

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        lineId: json['line_id'] as int,
        productId: json['product_id'] as int,
        name: json['name'] as String? ?? '',
        imageBase64: json['image_128'] as String?,
        uom: json['uom'] as String?,
        qty: json['qty'] as num? ?? 0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      );
}

/// État panier : reflète le devis Odoo (`sale.order` brouillon) du client
/// connecté (F06) — pas un panier local indépendant à resynchroniser plus
/// tard, cf. CLAUDE.md § Principe architecture Odoo. Le contrôleur
/// renvoie l'état complet du panier à chaque appel, donc chaque mutation
/// ici remplace simplement l'état en mémoire par la réponse.
class CartState extends ChangeNotifier {
  CartState(this._api);

  final OdooApiClient _api;

  List<CartLine> _lines = [];
  double _amountSubtotal = 0;
  double _amountTotal = 0;
  double _discount = 0;
  String? _verificationState;
  String? _state;

  List<CartLine> get lines => _lines;
  double get amountSubtotal => _amountSubtotal;
  double get amountTotal => _amountTotal;
  // F15 — négatif quand un code promo est appliqué (`order.reward_amount`
  // standard, module `sale_loyalty`), 0 sinon.
  double get discount => _discount;
  // Qualité clients — "pending"/"verified"/"rejected" (`res.partner.
  // x_verification_state`) : permet de bloquer "Valider mon panier" dès
  // cet écran plutôt qu'au bout du tunnel checkout (la vérification
  // définitive reste faite côté serveur à la confirmation).
  String? get verificationState => _verificationState;
  int get itemCount => _lines.length;
  bool get isEmpty => _lines.isEmpty;

  /// `true` tant que le devis courant est un vrai brouillon (`state ==
  /// 'draft'`) — bug signalé par l'utilisateur (2026-07-23) : une fois
  /// confirmée (`state == 'sent'`), la commande reste volontairement "le
  /// panier courant" côté serveur (modifiable tant qu'un opérateur ne l'a
  /// pas prise en charge, voir CLAUDE.md § Statuts de commande), mais ne
  /// doit plus jamais être présentée comme panier actif côté app.
  /// `CartBar`/`CartScreen` doivent se fier à ceci plutôt qu'à
  /// `itemCount`/`isEmpty` seuls pour décider de s'afficher.
  bool get isDraft => _state == 'draft';
  bool get hasActiveCart => isDraft && _lines.isNotEmpty;

  CartLine? _lineForProduct(int productId) {
    for (final line in _lines) {
      if (line.productId == productId) return line;
    }
    return null;
  }

  /// Quantité déjà au panier pour ce produit (0 si absent) — utilisé par
  /// `ProductGridTile` (Accueil/Catalogue/Recherche) pour savoir s'il faut
  /// afficher le bouton "Acheter" ou le sélecteur de quantité.
  num quantityFor(int productId) => _lineForProduct(productId)?.qty ?? 0;

  void _applyPayload(Map<String, dynamic> payload) {
    _lines = (payload['lines'] as List)
        .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
        .toList();
    _amountSubtotal = (payload['amount_subtotal'] as num?)?.toDouble() ?? 0;
    _amountTotal = (payload['amount_total'] as num?)?.toDouble() ?? 0;
    _discount = (payload['discount'] as num?)?.toDouble() ?? 0;
    _verificationState = payload['verification_state'] as String?;
    _state = payload['state'] as String?;
    notifyListeners();
  }

  /// Les erreurs (réseau, session...) ne sont pas attrapées ici : c'est à
  /// l'écran appelant de les afficher via `AppMessenger`, comme partout
  /// ailleurs dans l'app (cf. CLAUDE.md § Gestion des erreurs).
  Future<void> refresh() async => _applyPayload(await _api.getCart());

  /// Réinitialise l'état localement, SANS appel serveur — masque
  /// `CartBar` instantanément juste après une confirmation réussie, sans
  /// attendre l'aller-retour réseau d'un `refresh()`. Complète (ne
  /// remplace pas) `isDraft`/`hasActiveCart` : le devis passe en
  /// `state = 'sent'` à la confirmation et reste volontairement "le
  /// panier courant" côté serveur (`cart_controller.py._cart_order()`,
  /// domaine `draft`/`sent` — le client peut encore y ajouter des
  /// articles tant qu'un opérateur ne l'a pas pris en charge, voir
  /// CLAUDE.md § Statuts de commande) — un `refresh()` ultérieur (ex.
  /// ouverture de l'écran Panier) re-décrira correctement cette même
  /// commande, mais `hasActiveCart` restera `false` puisque `state !=
  /// 'draft'`, donc `CartBar` reste masquée même après ce refresh. Le
  /// prochain vrai ajout via `add()` resynchronise l'état serveur exact.
  void clearLocally() {
    _lines = [];
    _amountSubtotal = 0;
    _amountTotal = 0;
    _discount = 0;
    _verificationState = null;
    _state = null;
    notifyListeners();
  }

  Future<void> add({required int productId, num qty = 1, int? variantId}) async =>
      _applyPayload(await _api.addToCart(productId: productId, qty: qty, variantId: variantId));

  Future<void> updateQuantity({required int lineId, required num qty}) async =>
      _applyPayload(await _api.updateCartLine(lineId: lineId, qty: qty));

  Future<void> removeLine({required int lineId}) async =>
      _applyPayload(await _api.removeCartLine(lineId: lineId));

  /// Le contrôleur `/cart/add` incrémente déjà la ligne existante côté
  /// serveur (voir `cart_controller.py.add()`) — pas besoin de connaître
  /// le `lineId` pour ajouter une unité de plus.
  Future<void> incrementProduct(int productId) async => add(productId: productId, qty: 1);

  Future<void> decrementProduct(int productId) async {
    final line = _lineForProduct(productId);
    if (line == null) return;
    if (line.qty <= 1) {
      await removeLine(lineId: line.lineId);
    } else {
      await updateQuantity(lineId: line.lineId, qty: line.qty - 1);
    }
  }

  Future<void> applyPromoCode({required String code}) async =>
      _applyPayload(await _api.applyPromoCode(code: code));

  /// F09 — retourne les noms des lignes exclues (produits non vendables ou
  /// en rupture) pour que l'écran affiche l'avertissement.
  Future<List<String>> reorder({required int orderId}) async {
    final payload = await _api.reorder(orderId: orderId);
    _applyPayload(payload);
    return (payload['unavailable'] as List).cast<String>();
  }
}
