import '../errors/app_error.dart';

/// Longueur du code PIN — **écart volontaire par rapport aux specs**
/// (`docs/specs_phase1_echango_order.md` prévoit 4 chiffres) : décision
/// produit de passer à un PIN de 6 à 12 chiffres pour plus d'entropie.
/// Voir CLAUDE.md § Stack technique / notes de décision.
const int kPinMinLength = 6;
const int kPinMaxLength = 12;

// Format international générique (E.164) — les specs montrent un exemple
// algérien (+213...) mais aucune règle de format locale précise n'est
// donnée ; à affiner si l'Expert Odoo fournit une contrainte plus stricte.
final RegExp _phoneRegExp = RegExp(r'^\+[1-9]\d{7,14}$');
final RegExp _pinRegExp = RegExp('^\\d{$kPinMinLength,$kPinMaxLength}\$');

/// Fonctions de validation réutilisables. Retournent `null` si valide, sinon
/// l'[AppError] correspondante (à afficher via `AppMessenger`/un champ de
/// formulaire) — jamais de message en dur dans les écrans.
AppError? validateRequired(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const AppError(AppError.validationRequired);
  }
  return null;
}

AppError? validatePhone(String? value) {
  final requiredError = validateRequired(value);
  if (requiredError != null) return requiredError;
  if (!_phoneRegExp.hasMatch(value!.trim())) {
    return const AppError(AppError.validationInvalidPhone);
  }
  return null;
}

AppError? validatePin(String? value) {
  final requiredError = validateRequired(value);
  if (requiredError != null) return requiredError;
  if (!_pinRegExp.hasMatch(value!.trim())) {
    return const AppError(AppError.validationInvalidPin);
  }
  return null;
}

AppError? validatePinMatch(String pin, String confirmation) {
  if (pin != confirmation) {
    return const AppError(AppError.validationPinMismatch);
  }
  return null;
}
