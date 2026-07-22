import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../errors/app_error.dart';

/// Mappe les codes d'erreur renvoyés par `echango_order/controllers` vers
/// les constantes `AppError` déjà définies côté app — voir CLAUDE.md §
/// Gestion des erreurs : "les erreurs JSON-RPC d'Odoo devront être mappées
/// vers ces mêmes constantes... sans toucher à l'affichage ni aux
/// traductions déjà en place".
const _errorCodeMap = <String, String>{
  'validation.required': AppError.validationRequired,
  'validation.phone_required': AppError.validationRequired,
  'validation.pin_format': AppError.validationInvalidPin,
  'auth.phone_already_registered': AppError.authPhoneAlreadyUsed,
  'auth.invalid_credentials': AppError.authInvalidCredentials,
  'auth.account_locked': AppError.authPinLocked,
  // Renvoyé par require_fresh_session (controllers/session_utils.py) sur
  // les endpoints /echango/* — même code que l'expiration détectée au
  // niveau JSON-RPC (_mapRpcFault), doit déclencher la même bascule vers
  // ReauthPinScreen (voir _throwIfOwnError ci-dessous).
  'auth.session_expired': AppError.authSessionExpired,
  // Réutilise le code checkout existant : même message ("produit non
  // disponible") que le cas F07, pas la peine d'un nouveau domaine/2
  // traductions supplémentaires pour la même idée.
  'cart.product_unavailable': AppError.checkoutOutOfStock,
  // Cas normalement intercepté avant ce mapping générique par
  // [OdooApiClient.confirmOrder] (voir plus bas, [CartUnavailableProductsError]
  // porte la liste structurée des lignes) — gardé ici en repli défensif
  // seulement, pour ne jamais tomber sur `AppError.unknown` si ce code
  // apparaissait ailleurs un jour.
  'cart.unavailable_products': AppError.checkoutUnavailableProducts,
  'not_found': AppError.notFound,
  // Renvoyé par rate_limited (controllers/rate_limit.py) sur les
  // endpoints publics (auth/login, auth/register, currency, vitrine).
  'rate_limited': AppError.serverRateLimited,
  'checkout.out_of_delivery_zone': AppError.checkoutOutOfDeliveryZone,
  'checkout.slot_full': AppError.checkoutSlotFull,
  'order.cannot_cancel': AppError.orderCannotCancel,
  'promo.invalid': AppError.promoInvalid,
  'promo.expired': AppError.promoExpired,
  'promo.already_used': AppError.promoAlreadyUsed,
  'auth.account_pending_verification': AppError.authAccountPendingVerification,
  'auth.account_rejected': AppError.authAccountRejected,
};

/// Client JSON-RPC Odoo : les endpoints custom d'auth d'`echango_order`
/// (`/echango/auth/register`, `/echango/auth/login` — Odoo n'a pas de
/// notion de PIN, voir `controllers/auth_controller.py`) et le
/// `/web/dataset/call_kw` standard pour tout le reste une fois connecté
/// (catalogue, panier, commandes...) — cf. CLAUDE.md § Principe
/// architecture Odoo : pas de contrôleur custom là où le `call_kw`
/// standard suffit.
///
/// Session persistée via `flutter_secure_storage` (Keychain/Keystore, cf.
/// CLAUDE.md § Sécurité) : le cookie `session_id` survit au redémarrage de
/// l'app. Appeler [restoreSession] une fois au démarrage avant le premier
/// appel réseau. Aucune vérification proactive de validité au démarrage
/// (pas d'appel "ping") : si la session Odoo a expiré côté serveur, le
/// premier appel réel échoue avec [AppError.authSessionExpired], ce qui
/// déclenche [onSessionExpired].
class OdooApiClient {
  OdooApiClient({
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    this.onSessionExpired,
    this.onActivity,
  })  : _http = httpClient ?? http.Client(),
        // `encryptedSharedPreferences: true` explicite sur Android (recommandé
        // par le package pour garantir EncryptedSharedPreferences/Keystore
        // plutôt qu'une configuration par défaut moins robuste selon la
        // version — trouvé à l'audit sécurité du 2026-07-19). Sans effet sur
        // iOS, qui utilise déjà le Keychain nativement.
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static const _cookieStorageKey = 'echango_session_cookie';

  final http.Client _http;
  final FlutterSecureStorage _secureStorage;
  final VoidCallback? onSessionExpired;
  // Session expirée après 24h d'inactivité (CLAUDE.md § Exigences
  // transversales) : appelé après chaque appel réussi pour que
  // `AuthState.checkInactivity()` (vérifiée au lancement/retour au premier
  // plan) dispose d'un horodatage fiable de dernière activité.
  final VoidCallback? onActivity;
  String? _sessionCookie;

  Future<void> restoreSession() async {
    _sessionCookie = await _secureStorage.read(key: _cookieStorageKey);
  }

  Future<void> clearSession() async {
    _sessionCookie = null;
    await _secureStorage.delete(key: _cookieStorageKey);
  }

  Future<int> register({
    required String phone,
    required String pin,
    String? name,
    String? lang,
  }) async {
    final result = await _rpc('/echango/auth/register', {
      'phone': phone,
      'pin': pin,
      if (name != null) 'name': name,
      if (lang != null) 'lang': lang,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result['user_id'] as int;
  }

  Future<int> login({required String phone, required String pin}) async {
    final result =
        await _rpc('/echango/auth/login', {'phone': phone, 'pin': pin}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result['uid'] as int;
  }

  /// F02 — "PIN oublié" : pas de fournisseur SMS choisi (voir
  /// status-V1.md), donc pas de réinitialisation en libre-service. La
  /// demande crée une activité pour un modérateur back-office (même
  /// mécanisme que la validation de compte), qui recontacte le client par
  /// téléphone et réinitialise son PIN depuis Odoo. Réponse toujours
  /// générique côté serveur, que le numéro existe ou non — évite de
  /// pouvoir vérifier si un numéro est inscrit (énumération de comptes).
  Future<void> requestPinReset({required String phone}) async {
    await _rpc('/echango/auth/request_pin_reset', {'phone': phone});
  }

  /// `search_read` standard via `/web/dataset/call_kw` — pas de contrôleur
  /// custom pour la lecture de modèles Odoo standards (catalogue, etc.),
  /// seuls les droits d'accès portail sont accordés côté module
  /// (`security/ir.model.access.csv` + `ir_rule.xml`).
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    List<dynamic> domain = const [],
    required List<String> fields,
    int? limit,
    int offset = 0,
    String? order,
  }) async {
    final result = await _rpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': fields,
        if (limit != null) 'limit': limit,
        'offset': offset,
        if (order != null) 'order': order,
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// `formatted_read_group` standard : regroupe des enregistrements
  /// existants par champ (ex : produits par catégorie). Contrairement à un
  /// `search_read` sur le modèle "parent" (ici `product.category`), ça ne
  /// fait remonter que les groupes qui contiennent effectivement des
  /// enregistrements visibles — pas les catégories techniques vides côté
  /// portail.
  ///
  /// Remplace l'ancien `read_group`, déprécié depuis Odoo 19 (vérifié
  /// contre le code source, `addons/web/models/models.py`) — même
  /// représentation `[id, nom]` pour un champ many2one groupé, mais le
  /// comptage n'est plus implicite : il faut le demander explicitement via
  /// `aggregates` (clé `__count` dans le résultat, plus `<champ>_count`).
  Future<List<Map<String, dynamic>>> readGroup({
    required String model,
    List<dynamic> domain = const [],
    required List<String> groupBy,
    List<String> aggregates = const ['__count'],
  }) async {
    final result = await _rpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'formatted_read_group',
      'args': [domain, groupBy, aggregates],
      'kwargs': {},
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// `read` standard : un seul enregistrement par id connu (fiche produit,
  /// etc.) — plus direct qu'un `search_read` avec un domaine `[('id','=',..)]`.
  /// Lève [AppError.notFound] si l'id n'existe pas ou n'est pas visible
  /// (exclu par un `ir.rule`, ex : produit non vendable).
  Future<Map<String, dynamic>> read({
    required String model,
    required int id,
    required List<String> fields,
  }) async {
    final result = await _rpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'read',
      'args': [
        [id],
        fields,
      ],
      'kwargs': {},
    });
    final records = (result as List).cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      throw const AppError(AppError.notFound);
    }
    return records.first;
  }

  /// F06 — Panier = devis (`sale.order` brouillon) du client connecté.
  /// Contrôleurs custom (`controllers/cart_controller.py`) : Odoo réserve
  /// volontairement un accès lecture seule à `sale.order`/`sale.order.line`
  /// pour le groupe portail (vérifié contre le code source du module
  /// `sale`), donc pas de `call_kw` standard possible ici pour les
  /// mutations, contrairement au catalogue (F03-F05).
  Future<Map<String, dynamic>> getCart() async {
    final result = await _rpc('/echango/cart', {}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  /// [variantId] — variante précise choisie (F05, couleur/taille...),
  /// résolue côté app depuis [getVariants]. Omis pour un produit sans
  /// variante (ou tant qu'on veut la variante par défaut Odoo) — comporte-
  /// ment inchangé dans ce cas.
  Future<Map<String, dynamic>> addToCart({required int productId, num qty = 1, int? variantId}) async {
    final result = await _rpc('/echango/cart/add', {
      'product_id': productId,
      'qty': qty,
      if (variantId != null) 'variant_id': variantId,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<Map<String, dynamic>> updateCartLine({required int lineId, required num qty}) async {
    final result =
        await _rpc('/echango/cart/update', {'line_id': lineId, 'qty': qty}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<Map<String, dynamic>> removeCartLine({required int lineId}) async {
    final result = await _rpc('/echango/cart/remove', {'line_id': lineId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  /// F09 — recopie les lignes d'une commande passée dans le panier en
  /// cours (produits non vendables/en rupture exclus côté serveur, voir
  /// `cart_controller.py`). La réponse est l'état complet du panier
  /// (comme les autres mutations) + une clé `unavailable` (noms des
  /// lignes exclues, pour l'avertissement F09).
  Future<Map<String, dynamic>> reorder({required int orderId}) async {
    final result = await _rpc('/echango/cart/reorder', {'order_id': orderId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  /// F04/F05 — disponibilité stock + nombre de variantes, via un
  /// contrôleur étroit en `sudo()` plutôt que les champs calculés
  /// `qty_available`/`product_variant_count` exposés au portail via
  /// `call_kw` (cascade d'`AccessError` sur `product.product` puis
  /// `stock.warehouse`, voir status-V1.md § Points de vigilance —
  /// `product_variant_count` déclenche exactement le même problème,
  /// constaté par l'utilisateur, d'où son ajout ici plutôt que dans les
  /// `fields` d'un `search_read` direct). Les deux viennent du même
  /// `search()` de templates côté serveur, réunis dans un seul appel
  /// plutôt que deux endpoints séparés pour éviter un aller-retour de
  /// plus sur les grilles (Accueil/Recherche), qui appellent déjà
  /// `getPromotions` en parallèle.
  Future<({Map<int, double> stock, Map<int, int> variantCounts})> getStock({
    required List<int> productIds,
  }) async {
    if (productIds.isEmpty) return (stock: <int, double>{}, variantCounts: <int, int>{});
    final result =
        await _rpc('/echango/catalog/stock', {'product_ids': productIds}) as Map<String, dynamic>;
    final stock = result['stock'] as Map<String, dynamic>;
    final variantCounts = result['variant_counts'] as Map<String, dynamic>;
    return (
      stock: stock.map((key, value) => MapEntry(int.parse(key), (value as num).toDouble())),
      variantCounts: variantCounts.map((key, value) => MapEntry(int.parse(key), (value as num).toInt())),
    );
  }

  /// Badge "Promo" (module standard `loyalty`, promotions automatiques
  /// sur des produits précis — voir `controllers/catalog_controller.py`).
  /// Valeur `null` : produit en promo mais remise non exprimée en
  /// pourcentage (montant fixe/par point) — badge affiché sans %.
  Future<Map<int, double?>> getPromotions({required List<int> productIds}) async {
    if (productIds.isEmpty) return {};
    final result =
        await _rpc('/echango/catalog/promotions', {'product_ids': productIds}) as Map<String, dynamic>;
    final promotions = result['promotions'] as Map<String, dynamic>;
    return promotions.map((key, value) => MapEntry(int.parse(key), (value as num?)?.toDouble()));
  }

  /// Devise réellement configurée sur la société (`res.company.currency_id`)
  /// — remplace le "€" auparavant en dur partout dans l'app. `auth="public"`
  /// côté serveur : appelable avant connexion (F00 vitrine).
  Future<Map<String, String>> getCurrency() async {
    final result = await _rpc('/echango/currency', {}) as Map<String, dynamic>;
    return {
      'symbol': result['symbol'] as String? ?? '€',
      'position': result['position'] as String? ?? 'after',
    };
  }

  /// F07 — vérifie qu'une ville/code postal est dans une `x_delivery_zone`
  /// configurée en back-office. Modèle non exposé au portail (voir
  /// `controllers/checkout_controller.py`), d'où l'appel dédié plutôt
  /// qu'un `search_read` standard.
  Future<bool> checkDeliveryZone({required String city, required String zipCode}) async {
    final result = await _rpc('/echango/checkout/check_zone', {
      'city': city,
      'zip_code': zipCode,
    }) as Map<String, dynamic>;
    return result['covered'] as bool? ?? false;
  }

  /// F07 — capacité des créneaux ("créneau complet grisé", specs QA).
  /// `slots` = créneaux candidats déjà générés côté client
  /// (`utils/timeslots.dart`, seule source de vérité pour les horaires
  /// proposés) — l'heure locale (`slot.hour`) est transmise séparément du
  /// datetime déjà converti en UTC (`formatOdooDatetime`), la capacité
  /// back-office étant exprimée en heure locale (voir
  /// `checkout_controller.py.timeslots`). Renvoie le sous-ensemble complet.
  Future<Set<DateTime>> fetchFullTimeslots({
    required String receptionMode,
    required List<DateTime> slots,
  }) async {
    final result = await _rpc('/echango/checkout/timeslots', {
      'reception_mode': receptionMode,
      'slots': [
        for (final slot in slots) {'start': formatOdooDatetime(slot), 'hour': slot.hour},
      ],
    }) as Map<String, dynamic>;
    final fullStarts = (result['full'] as List).cast<String>().toSet();
    return slots.where((s) => fullStarts.contains(formatOdooDatetime(s))).toSet();
  }

  /// F07 — fixe le mode de réception/l'adresse/le créneau sur le devis en
  /// cours et le confirme (`action_confirm`, `state` -> `sale`). Le panier
  /// (F06) redevient vide juste après, puisqu'il n'y a alors plus de devis
  /// à l'état brouillon pour ce client.
  Future<Map<String, dynamic>> confirmOrder({
    required String receptionMode,
    required DateTime slotStart,
    int? addressId,
    String? street,
    String? city,
    String? zipCode,
    String? notes,
  }) async {
    final result = await _rpc('/echango/checkout/confirm', {
      'reception_mode': receptionMode,
      'slot_start': formatOdooDatetime(slotStart),
      // Heure locale du créneau (voir fetchFullTimeslots) : nécessaire
      // pour que la vérification de capacité côté serveur regarde la
      // bonne configuration (`x_timeslot_capacity.hour`, exprimée en
      // heure locale, pas en UTC).
      'slot_hour': slotStart.hour,
      // Adresse sauvegardée (F10) : addressId prioritaire côté serveur,
      // street/city/zipCode/notes ignorés dans ce cas (voir
      // checkout_controller.py.confirm) mais transmis quand même, sans
      // effet, pour garder confirmOrder() simple à appeler dans les deux
      // cas plutôt que deux méthodes distinctes.
      if (addressId != null) 'address_id': addressId,
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (zipCode != null) 'zip_code': zipCode,
      if (notes != null) 'notes': notes,
    }) as Map<String, dynamic>;
    // Un ou plusieurs produits sont devenus indisponibles entre l'ajout au
    // panier et la confirmation (voir checkout_controller.py.confirm()) :
    // intercepté avant `_throwIfOwnError` (générique) pour porter la liste
    // structurée des lignes/substituts jusqu'à l'écran de résolution
    // (`CheckoutResolveUnavailableScreen`) plutôt qu'un simple message
    // d'erreur.
    if (result['error'] == 'cart.unavailable_products') {
      throw CartUnavailableProductsError(
        (result['unavailable_lines'] as List).cast<Map<String, dynamic>>(),
      );
    }
    _throwIfOwnError(result);
    return result;
  }

  /// F15 — applique un code promo au panier en cours (module standard
  /// `sale_loyalty`/`loyalty`, voir `controllers/checkout_controller.py`).
  /// Retourne le panier mis à jour (réduction déjà reflétée dans
  /// `amount_total`/`discount`) — un seul code actif par commande, un
  /// nouvel appel remplace le précédent plutôt que de les cumuler.
  Future<Map<String, dynamic>> applyPromoCode({required String code}) async {
    final result = await _rpc('/echango/checkout/apply_promo', {'code': code}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  /// F10 — profil utilisateur. `res.partner`/`res.users` en lecture seule
  /// pour le portail (vérifié contre le code source de `base`), toute
  /// écriture passe par `controllers/profile_controller.py` en `sudo()`.
  Future<Map<String, dynamic>> getProfile() async {
    final result = await _rpc('/echango/profile', {}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<void> updateProfileName({required String name}) async {
    final result = await _rpc('/echango/profile/update_name', {'name': name}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  Future<void> changePin({required String currentPin, required String newPin}) async {
    final result = await _rpc('/echango/profile/change_pin', {
      'current_pin': currentPin,
      'new_pin': newPin,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  Future<List<Map<String, dynamic>>> listAddresses() async {
    final result = await _rpc('/echango/profile/addresses', {}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return (result['addresses'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addAddress({
    String? name,
    required String street,
    required String city,
    String? zipCode,
    String? comment,
    bool favorite = false,
    double? latitude,
    double? longitude,
  }) async {
    final result = await _rpc('/echango/profile/addresses/add', {
      'name': name,
      'street': street,
      'city': city,
      'zip_code': zipCode,
      'comment': comment,
      'favorite': favorite,
      'latitude': latitude,
      'longitude': longitude,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<Map<String, dynamic>> updateAddress({
    required int addressId,
    String? name,
    required String street,
    required String city,
    String? zipCode,
    String? comment,
    bool? favorite,
    double? latitude,
    double? longitude,
  }) async {
    final result = await _rpc('/echango/profile/addresses/update', {
      'address_id': addressId,
      'name': name,
      'street': street,
      'city': city,
      'zip_code': zipCode,
      'comment': comment,
      'favorite': favorite,
      'latitude': latitude,
      'longitude': longitude,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<void> removeAddress({required int addressId}) async {
    final result = await _rpc('/echango/profile/addresses/remove', {
      'address_id': addressId,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  Future<void> deleteAccount({required String pin}) async {
    final result = await _rpc('/echango/profile/delete_account', {'pin': pin}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  /// F09 — historique des commandes du client connecté. Endpoint custom
  /// plutôt qu'un `search_read` direct sur `sale.order` : ce dernier
  /// échappe à la politique "session expirée après 24h d'inactivité"
  /// (`require_fresh_session` ne couvre que les contrôleurs `/echango/*`,
  /// trouvé à l'audit sécurité du 2026-07-19 — voir status-V1.md), alors
  /// que l'historique de commandes reste une donnée personnelle.
  Future<List<Map<String, dynamic>>> listOrders({int offset = 0, int? limit}) async {
    final result = await _rpc('/echango/order/list', {
      'offset': offset,
      if (limit != null) 'limit': limit,
    }) as Map<String, dynamic>;
    return (result['orders'] as List).cast<Map<String, dynamic>>();
  }

  /// F08/F09 — détail + lignes d'une commande (suivi). Même raison que
  /// [listOrders] ci-dessus.
  Future<Map<String, dynamic>> getOrderDetail({required String orderRef}) async {
    final result = await _rpc('/echango/order/detail', {'order_ref': orderRef}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  /// F16 — annulation, uniquement tant que la commande est "Confirmée"
  /// (voir `controllers/order_controller.py` pour la règle exacte).
  Future<void> cancelOrder({required int orderId}) async {
    final result = await _rpc('/echango/order/cancel', {'order_id': orderId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  /// F05 — produits de substitution affichés sur la fiche produit
  /// (curation manuelle admin, `x_substitute_product_ids` — voir
  /// `models/product_template.py`, décision produit qui remplace l'ancien
  /// F17). Résolution en `sudo()` côté serveur (nom/prix/image), pas juste
  /// les ids du champ Many2many.
  Future<List<Map<String, dynamic>>> getSubstitutes({required int productId}) async {
    final result =
        await _rpc('/echango/catalog/substitutes', {'product_id': productId}) as Map<String, dynamic>;
    return (result['substitutes'] as List).cast<Map<String, dynamic>>();
  }

  /// F05 — attributs (couleur/taille...) et variantes d'un produit
  /// (mécanisme standard Odoo, `attribute_line_ids`/`product_variant_ids`
  /// — jusqu'ici ignoré par l'app, qui n'ajoutait toujours que la variante
  /// par défaut). `attributes` vide = produit sans variante, rien à
  /// afficher. Voir `catalog_controller.py.variants()`.
  Future<Map<String, dynamic>> getVariants({required int productId}) async {
    final result =
        await _rpc('/echango/catalog/variants', {'product_id': productId}) as Map<String, dynamic>;
    return result;
  }

  /// F00 — vitrine publique, aucune session requise (`auth='public'` côté
  /// Odoo, voir `controllers/vitrine_controller.py`) : utilisable avant
  /// toute inscription/connexion.
  Future<List<Map<String, dynamic>>> getVitrineProducts() async {
    final result = await _rpc('/echango/vitrine/products', {}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return (result['products'] as List).cast<Map<String, dynamic>>();
  }

  /// Liste de favoris — initialisée automatiquement à chaque commande
  /// confirmée (produits achetés, dédupliqués), modifiable manuellement
  /// ensuite (voir `controllers/favorites_controller.py`).
  /// `limit` reste `null` (défaut) pour `FavoritesState`, qui a besoin de
  /// l'ensemble complet des ids favoris — seul l'écran "Mes favoris" passe
  /// `limit` explicitement, pour sa pagination.
  Future<List<Map<String, dynamic>>> getFavorites({int? limit, int offset = 0}) async {
    final result = await _rpc('/echango/favorites', {
      if (limit != null) 'limit': limit,
      'offset': offset,
    }) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return (result['products'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> addFavorite({required int productId}) async {
    final result = await _rpc('/echango/favorites/add', {'product_id': productId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  Future<void> removeFavorite({required int productId}) async {
    final result = await _rpc('/echango/favorites/remove', {'product_id': productId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  /// Vérifie la forme d'erreur propre à nos contrôleurs custom
  /// (`{"error": "auth.xxx"}`) — pas celle des appels `call_kw` standards,
  /// dont les erreurs remontent au niveau JSON-RPC (`body['error']`, géré
  /// dans [_rpc]).
  void _throwIfOwnError(Map<String, dynamic> result) {
    final errorCode = result['error'] as String?;
    if (errorCode != null) {
      final mapped = _errorCodeMap[errorCode] ?? AppError.unknown;
      if (mapped == AppError.authSessionExpired) {
        onSessionExpired?.call();
      }
      throw AppError(mapped, cause: errorCode);
    }
  }

  Future<dynamic> _rpc(String path, Map<String, dynamic> params) async {
    http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$odooBaseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (_sessionCookie != null) 'Cookie': _sessionCookie!,
            },
            body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e) {
      throw AppError(AppError.networkTimeout, cause: e);
    } on SocketException catch (e) {
      throw AppError(AppError.networkOffline, cause: e);
    }

    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      _sessionCookie = setCookie.split(';').first;
      await _secureStorage.write(key: _cookieStorageKey, value: _sessionCookie);
    }

    if (response.statusCode != 200) {
      throw AppError(AppError.serverUnavailable, cause: response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      final code = _mapRpcFault(body['error']);
      if (code == AppError.authSessionExpired) {
        onSessionExpired?.call();
      }
      throw AppError(code, cause: body['error']);
    }
    onActivity?.call();
    return body['result'];
  }

  /// Erreur JSON-RPC de niveau Odoo (pas la nôtre) : la session expirée est
  /// le seul cas qu'on distingue explicitement (constante `AppError`
  /// existante), le reste (bug, droits manquants...) reste générique.
  String _mapRpcFault(dynamic error) {
    final name = error is Map ? (error['data']?['name'] as String?) : null;
    if (name != null && name.contains('SessionExpired')) {
      return AppError.authSessionExpired;
    }
    return AppError.serverUnknown;
  }
}

/// `DateTime` -> format attendu par les champs `Datetime` d'Odoo côté
/// JSON-RPC (`YYYY-MM-DD HH:MM:SS`, pas de `T` ni de fuseau). Les champs
/// `Datetime` d'Odoo sont toujours stockés en UTC côté serveur : on
/// convertit donc explicitement `dt` (heure locale de l'appareil, ex.
/// créneau choisi par l'utilisateur) en UTC avant de le formater, sinon
/// Odoo stocke l'heure locale telle quelle en la traitant comme de l'UTC
/// (décalage silencieux égal au fuseau du serveur/appareil). Symétrique de
/// [parseOdooDatetime].
String formatOdooDatetime(DateTime dt) {
  final utc = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}

/// Inverse de [formatOdooDatetime] : parse une chaîne `Datetime` renvoyée
/// par Odoo (toujours en UTC, sans suffixe de fuseau — format serveur
/// `YYYY-MM-DD HH:MM:SS` ou `isoformat()` avec `T`) et renvoie l'heure
/// locale de l'appareil. `DateTime.parse`/`tryParse` traiterait une chaîne
/// sans fuseau comme déjà locale, d'où le suffixe `Z` ajouté explicitement
/// avant parsing.
DateTime? parseOdooDatetime(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.contains('T') ? value : value.replaceFirst(' ', 'T');
  return DateTime.tryParse('${normalized}Z')?.toLocal();
}
