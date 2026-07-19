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
  // Réutilise le code checkout existant : même message ("produit non
  // disponible") que le cas F07, pas la peine d'un nouveau domaine/2
  // traductions supplémentaires pour la même idée.
  'cart.product_unavailable': AppError.checkoutOutOfStock,
  'not_found': AppError.notFound,
  'checkout.out_of_delivery_zone': AppError.checkoutOutOfDeliveryZone,
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
  OdooApiClient({http.Client? httpClient, FlutterSecureStorage? secureStorage, this.onSessionExpired})
      : _http = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _cookieStorageKey = 'echango_session_cookie';

  final http.Client _http;
  final FlutterSecureStorage _secureStorage;
  final VoidCallback? onSessionExpired;
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

  Future<Map<String, dynamic>> addToCart({required int productId, num qty = 1}) async {
    final result =
        await _rpc('/echango/cart/add', {'product_id': productId, 'qty': qty}) as Map<String, dynamic>;
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

  /// F04/F05 — disponibilité stock, via un contrôleur étroit en `sudo()`
  /// plutôt que le champ calculé `qty_available` exposé au portail via
  /// `call_kw` (cascade d'`AccessError` sur `product.product` puis
  /// `stock.warehouse`, voir status-V1.md § Points de vigilance).
  Future<Map<int, double>> getStock({required List<int> productIds}) async {
    if (productIds.isEmpty) return {};
    final result =
        await _rpc('/echango/catalog/stock', {'product_ids': productIds}) as Map<String, dynamic>;
    final stock = result['stock'] as Map<String, dynamic>;
    return stock.map((key, value) => MapEntry(int.parse(key), (value as num).toDouble()));
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

  /// F07 — fixe le mode de réception/l'adresse/le créneau sur le devis en
  /// cours et le confirme (`action_confirm`, `state` -> `sale`). Le panier
  /// (F06) redevient vide juste après, puisqu'il n'y a alors plus de devis
  /// à l'état brouillon pour ce client.
  Future<Map<String, dynamic>> confirmOrder({
    required String receptionMode,
    required DateTime slotStart,
    String? street,
    String? city,
    String? zipCode,
    String? notes,
  }) async {
    final result = await _rpc('/echango/checkout/confirm', {
      'reception_mode': receptionMode,
      'slot_start': formatOdooDatetime(slotStart),
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (zipCode != null) 'zip_code': zipCode,
      if (notes != null) 'notes': notes,
    }) as Map<String, dynamic>;
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

  /// F16 — annulation, uniquement tant que la commande est "Confirmée"
  /// (voir `controllers/order_controller.py` pour la règle exacte).
  Future<void> cancelOrder({required int orderId}) async {
    final result = await _rpc('/echango/order/cancel', {'order_id': orderId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  /// F17 — la substitution est signalée manuellement par le préparateur en
  /// back-office (`x_substitution_produit`, voir `models/sale_order.py`) ;
  /// `pending: false` si aucune substitution n'est en attente pour cette
  /// commande.
  Future<Map<String, dynamic>> getSubstitution({required int orderId}) async {
    final result = await _rpc('/echango/order/substitution', {'order_id': orderId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
    return result;
  }

  Future<void> acceptSubstitution({required int lineId}) async {
    final result =
        await _rpc('/echango/order/substitution/accept', {'line_id': lineId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
  }

  Future<void> refuseSubstitution({required int lineId}) async {
    final result =
        await _rpc('/echango/order/substitution/refuse', {'line_id': lineId}) as Map<String, dynamic>;
    _throwIfOwnError(result);
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
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final result = await _rpc('/echango/favorites', {}) as Map<String, dynamic>;
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
      throw AppError(_errorCodeMap[errorCode] ?? AppError.unknown, cause: errorCode);
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
/// JSON-RPC (`YYYY-MM-DD HH:MM:SS`, pas de `T` ni de fuseau — `toIso8601String()`
/// ne convient pas). Simplification MVP : pas de conversion UTC, on
/// suppose serveur et client dans le même fuseau horaire (déploiement
/// régional) — à revoir avant une release multi-fuseaux.
String formatOdooDatetime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}
