import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
};

/// Client JSON-RPC Odoo : les endpoints custom d'auth d'`echango_order`
/// (`/echango/auth/register`, `/echango/auth/login` — Odoo n'a pas de
/// notion de PIN, voir `controllers/auth_controller.py`) et le
/// `/web/dataset/call_kw` standard pour tout le reste une fois connecté
/// (catalogue, panier, commandes...) — cf. CLAUDE.md § Principe
/// architecture Odoo : pas de contrôleur custom là où le `call_kw`
/// standard suffit.
///
/// Gestion de session volontairement minimale pour cette première passe :
/// le cookie `session_id` renvoyé par Odoo est gardé en mémoire (pas
/// persisté), donc perdu au redémarrage de l'app — le stockage sécurisé
/// (`flutter_secure_storage`, cf. status-V1.md) reste à ajouter avant
/// une vraie gestion de session 24h.
class OdooApiClient {
  OdooApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  String? _sessionCookie;

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
  }) async {
    final result = await _rpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': fields,
        if (limit != null) 'limit': limit,
        'offset': offset,
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
    }

    if (response.statusCode != 200) {
      throw AppError(AppError.serverUnavailable, cause: response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw AppError(_mapRpcFault(body['error']), cause: body['error']);
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
