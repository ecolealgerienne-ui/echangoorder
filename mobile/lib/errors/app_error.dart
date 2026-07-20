/// Erreur applicative typée par un **code**, pas par un message en dur.
///
/// Convention : `code` est un chemin en points qui correspond exactement à
/// une clé dans `errors.*` des fichiers `assets/translations/*.json`
/// (ex : code `network.offline` → traduction `errors.network.offline`).
/// Ça permet à un·e traducteur·rice de ne toucher QUE les fichiers JSON,
/// jamais le code Dart, et prépare le terrain pour les erreurs Odoo
/// (JSON-RPC renvoie ses propres codes/`data.name` qu'on mappera vers ces
/// mêmes constantes au moment du branchement F02+).
///
/// Ne jamais afficher `cause`/`detail` à l'utilisateur — réservés aux logs.
class AppError implements Exception {
  final String code;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.code, {this.cause, this.stackTrace});

  /// Clé de traduction correspondante (`errors.<code>`), avec repli sur
  /// `errors.unknown` si jamais un code n'a pas encore d'entrée i18n.
  String get translationKey => 'errors.$code';

  @override
  String toString() => 'AppError($code${cause != null ? ', cause: $cause' : ''})';

  // --- Réseau ---
  static const networkOffline = 'network.offline';
  static const networkTimeout = 'network.timeout';
  static const networkUnknown = 'network.unknown';

  // --- Serveur / Odoo ---
  static const serverUnavailable = 'server.unavailable';
  static const serverUnknown = 'server.unknown';
  static const serverRateLimited = 'server.rate_limited';
  static const notFound = 'not_found';

  // --- Authentification (F02) ---
  static const authInvalidCredentials = 'auth.invalid_credentials';
  static const authPhoneAlreadyUsed = 'auth.phone_already_used';
  static const authSessionExpired = 'auth.session_expired';
  static const authPinLocked = 'auth.pin_locked';
  static const authAccountPendingVerification = 'auth.account_pending_verification';
  static const authAccountRejected = 'auth.account_rejected';

  // --- Validation formulaire ---
  static const validationRequired = 'validation.required';
  static const validationInvalidPhone = 'validation.invalid_phone';
  static const validationInvalidPin = 'validation.invalid_pin';
  static const validationPinMismatch = 'validation.pin_mismatch';

  // --- Checkout (F07) ---
  static const checkoutOutOfStock = 'checkout.out_of_stock';
  static const checkoutSlotFull = 'checkout.slot_full';
  static const checkoutOutOfDeliveryZone = 'checkout.out_of_delivery_zone';
  static const checkoutUnavailableProducts = 'checkout.unavailable_products';

  // --- Code promo (F15) ---
  static const promoInvalid = 'promo.invalid';
  static const promoExpired = 'promo.expired';
  static const promoAlreadyUsed = 'promo.already_used';

  // --- Commande (F16) ---
  static const orderCannotCancel = 'order.cannot_cancel';

  // --- Permissions (F14) ---
  static const permissionDenied = 'permissions.denied';

  static const unknown = 'unknown';
}

/// F07 — un ou plusieurs produits du panier sont devenus indisponibles à la
/// confirmation (voir `checkout_controller.py.confirm()`). Contrairement
/// aux autres erreurs, celle-ci porte les données nécessaires pour que le
/// client résolve directement (remplacer par un substitut pré-défini par
/// l'admin, ou supprimer la ligne — jamais le préparateur, décision produit
/// qui remplace l'ancien F17) au lieu d'un simple message d'erreur. Étend
/// [AppError] pour rester compatible avec le code existant qui n'attrape
/// que `on AppError` ; les écrans qui doivent gérer la résolution
/// attrapent `on CartUnavailableProductsError` explicitement, avant le
/// `catch` générique.
class CartUnavailableProductsError extends AppError {
  final List<Map<String, dynamic>> lines;

  const CartUnavailableProductsError(this.lines) : super(AppError.checkoutUnavailableProducts);
}
