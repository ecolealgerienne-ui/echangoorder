import 'package:flutter/foundation.dart';

enum SessionStatus { unauthenticated, guest, authenticated }

/// État de session local, utilisé pour piloter la navigation (routes
/// publiques vs onglets principaux). Pas une simulation de backend :
/// sera conservé après le branchement Odoo (F02), seul le contenu du
/// login réel changera. `ChangeNotifier` pour être passé en
/// `refreshListenable` à GoRouter (redirection auto sur changement d'état).
class AuthState extends ChangeNotifier {
  SessionStatus _status = SessionStatus.unauthenticated;
  bool _hasSeenOnboarding = false;

  SessionStatus get status => _status;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isAuthenticated => _status != SessionStatus.unauthenticated;

  void completeOnboarding() {
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  void loginAsUser() {
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  void continueAsGuest() {
    _status = SessionStatus.guest;
    notifyListeners();
  }

  void logout() {
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }
}
