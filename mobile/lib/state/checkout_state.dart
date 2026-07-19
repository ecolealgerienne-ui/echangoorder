import 'package:flutter/foundation.dart';

enum ReceptionMode { delivery, pickup }

/// État éphémère du tunnel de commande (F07) : mode de réception, adresse,
/// créneau — vit le temps du parcours Panier → Confirmation, remis à zéro
/// via [reset] à chaque nouvelle entrée dans le tunnel (`CartScreen`) et
/// après une confirmation réussie. Pas persisté (contrairement à
/// `AuthState`/`CartState`) : rien d'utile à retrouver après un
/// redémarrage de l'app au milieu d'un checkout non confirmé.
class CheckoutState extends ChangeNotifier {
  ReceptionMode? _receptionMode;
  // F10 — adresse sauvegardée choisie au checkout (`res.partner` enfant,
  // voir checkout_controller.py.confirm) plutôt qu'une adresse ressaisie :
  // null si l'utilisateur a rempli le formulaire libre (nouvelle adresse,
  // pas encore sauvegardée). street/city/zipCode/notes sont renseignés
  // dans les deux cas (juste pour affichage au récapitulatif, voir
  // CheckoutSummaryScreen), addressId seul détermine le comportement côté
  // serveur.
  int? _addressId;
  String _street = '';
  String _city = '';
  String _zipCode = '';
  String _notes = '';
  DateTime? _slotStart;

  ReceptionMode? get receptionMode => _receptionMode;
  int? get addressId => _addressId;
  String get street => _street;
  String get city => _city;
  String get zipCode => _zipCode;
  String get notes => _notes;
  DateTime? get slotStart => _slotStart;

  void setReceptionMode(ReceptionMode mode) {
    _receptionMode = mode;
    notifyListeners();
  }

  void setAddress({
    required String street,
    required String city,
    required String zipCode,
    String notes = '',
    int? addressId,
  }) {
    _addressId = addressId;
    _street = street;
    _city = city;
    _zipCode = zipCode;
    _notes = notes;
    notifyListeners();
  }

  void setSlot(DateTime start) {
    _slotStart = start;
    notifyListeners();
  }

  void reset() {
    _receptionMode = null;
    _addressId = null;
    _street = '';
    _city = '';
    _zipCode = '';
    _notes = '';
    _slotStart = null;
    notifyListeners();
  }
}
