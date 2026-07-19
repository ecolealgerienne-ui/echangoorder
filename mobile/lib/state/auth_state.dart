import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionStatus { unauthenticated, guest, authenticated, sessionExpired }

const _statusPrefsKey = 'echango_session_status';
const _onboardingPrefsKey = 'echango_has_seen_onboarding';
const _phonePrefsKey = 'echango_session_phone';
const _lastActivityPrefsKey = 'echango_last_activity';

/// Session expirée après 24h d'inactivité (CLAUDE.md § Exigences
/// transversales) — vérifiée côté client (app relancée/reprise au premier
/// plan) en complément du durcissement serveur sur les endpoints
/// `/echango/*` (`controllers/session_utils.py`, champ `x_last_activity`).
const sessionInactivityLimit = Duration(hours: 24);

/// État de session local, utilisé pour piloter la navigation (routes
/// publiques vs onglets principaux). Pas une simulation de backend :
/// sera conservé après le branchement Odoo (F02), seul le contenu du
/// login réel changera. `ChangeNotifier` pour être passé en
/// `refreshListenable` à GoRouter (redirection auto sur changement d'état).
///
/// Persisté localement (`shared_preferences`) pour survivre au redémarrage
/// de l'app pendant cette phase sans backend — sera remplacé par le vrai
/// token de session Odoo (stocké de façon sécurisée) une fois F02 branché.
class AuthState extends ChangeNotifier {
  AuthState(this._prefs)
      : _status = _statusFromString(_prefs.getString(_statusPrefsKey)),
        _hasSeenOnboarding = _prefs.getBool(_onboardingPrefsKey) ?? false,
        _phone = _prefs.getString(_phonePrefsKey);

  final SharedPreferences _prefs;
  SessionStatus _status;
  bool _hasSeenOnboarding;
  String? _phone;

  SessionStatus get status => _status;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isAuthenticated => _status == SessionStatus.authenticated || _status == SessionStatus.guest;
  bool get isSessionExpired => _status == SessionStatus.sessionExpired;
  // Connu tant qu'un compte s'est authentifié au moins une fois sur
  // l'appareil (pas effacé par expireSession(), seulement par logout()) —
  // permet à ReauthPinScreen de ne redemander que le PIN, pas le téléphone.
  String? get phone => _phone;

  void completeOnboarding() {
    _hasSeenOnboarding = true;
    _prefs.setBool(_onboardingPrefsKey, true);
    notifyListeners();
  }

  void loginAsUser({required String phone}) {
    _phone = phone;
    _prefs.setString(_phonePrefsKey, phone);
    touchActivity();
    _setStatus(SessionStatus.authenticated);
  }

  void continueAsGuest() => _setStatus(SessionStatus.guest);

  void logout() {
    _phone = null;
    _prefs.remove(_phonePrefsKey);
    _prefs.remove(_lastActivityPrefsKey);
    _setStatus(SessionStatus.unauthenticated);
  }

  /// Session terminée côté serveur ou par inactivité prolongée : contrairement
  /// à [logout], le téléphone est conservé pour permettre une
  /// ré-authentification par PIN seul (`ReauthPinScreen`) plutôt qu'un
  /// retour complet à l'écran de connexion. Repli sur [logout] si aucun
  /// téléphone n'est connu (ex. session issue d'une version antérieure de
  /// l'app, avant l'introduction de cette persistance).
  void expireSession() {
    if (_phone == null) {
      logout();
      return;
    }
    _setStatus(SessionStatus.sessionExpired);
  }

  void touchActivity() {
    _prefs.setInt(_lastActivityPrefsKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// À appeler au lancement de l'app et à chaque retour au premier plan.
  /// N'a d'effet que si une session authentifiée est en cours : bascule
  /// vers [expireSession] si plus de [sessionInactivityLimit] s'est
  /// écoulé depuis le dernier appel réussi à l'API ([touchActivity]).
  void checkInactivity() {
    if (_status != SessionStatus.authenticated) return;
    final lastMillis = _prefs.getInt(_lastActivityPrefsKey);
    if (lastMillis == null) return;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    if (DateTime.now().difference(last) > sessionInactivityLimit) {
      expireSession();
    }
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    _prefs.setString(_statusPrefsKey, status.name);
    notifyListeners();
  }

  static SessionStatus _statusFromString(String? value) {
    return SessionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SessionStatus.unauthenticated,
    );
  }
}
