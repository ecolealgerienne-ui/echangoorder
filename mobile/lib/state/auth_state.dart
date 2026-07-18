import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionStatus { unauthenticated, guest, authenticated }

const _statusPrefsKey = 'echango_session_status';
const _onboardingPrefsKey = 'echango_has_seen_onboarding';

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
        _hasSeenOnboarding = _prefs.getBool(_onboardingPrefsKey) ?? false;

  final SharedPreferences _prefs;
  SessionStatus _status;
  bool _hasSeenOnboarding;

  SessionStatus get status => _status;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isAuthenticated => _status != SessionStatus.unauthenticated;

  void completeOnboarding() {
    _hasSeenOnboarding = true;
    _prefs.setBool(_onboardingPrefsKey, true);
    notifyListeners();
  }

  void loginAsUser() => _setStatus(SessionStatus.authenticated);

  void continueAsGuest() => _setStatus(SessionStatus.guest);

  void logout() => _setStatus(SessionStatus.unauthenticated);

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
