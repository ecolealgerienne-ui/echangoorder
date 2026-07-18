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
