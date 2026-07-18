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

/// Client JSON-RPC pour les endpoints custom d'auth d'`echango_order`
/// (`/echango/auth/register`, `/echango/auth/login`) — voir
/// `backend/addons/echango_order/controllers/auth_controller.py`.
///
/// Une fois connecté, le reste des appels (catalogue, panier, commandes...)
/// passera par le `/web/dataset/call_kw` standard d'Odoo ; ce client ne
/// gère que ce que ces deux endpoints custom exposent pour l'instant.
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
    final result = await _call('/echango/auth/register', {
      'phone': phone,
      'pin': pin,
      if (name != null) 'name': name,
      if (lang != null) 'lang': lang,
    });
    return result['user_id'] as int;
  }

  Future<int> login({required String phone, required String pin}) async {
    final result = await _call('/echango/auth/login', {'phone': phone, 'pin': pin});
    return result['uid'] as int;
  }

  Future<Map<String, dynamic>> _call(String path, Map<String, dynamic> params) async {
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
      // Exception Odoo non anticipée par le contrôleur (bug serveur,
      // signature interne incompatible...) — pas un cas métier attendu.
      throw AppError(AppError.serverUnknown, cause: body['error']);
    }

    final result = body['result'] as Map<String, dynamic>;
    final errorCode = result['error'] as String?;
    if (errorCode != null) {
      throw AppError(_errorCodeMap[errorCode] ?? AppError.unknown, cause: errorCode);
    }
    return result;
  }
}
