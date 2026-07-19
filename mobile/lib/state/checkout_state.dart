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
  String _street = '';
  String _city = '';
  String _zipCode = '';
  String _notes = '';
  DateTime? _slotStart;

  ReceptionMode? get receptionMode => _receptionMode;
  String get street => _street;
  String get city => _city;
  String get zipCode => _zipCode;
  String get notes => _notes;
  DateTime? get slotStart => _slotStart;

  void setReceptionMode(ReceptionMode mode) {
    _receptionMode = mode;
    notifyListeners();
  }

  void setAddress({required String street, required String city, required String zipCode, String notes = ''}) {
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
    _street = '';
    _city = '';
    _zipCode = '';
    _notes = '';
    _slotStart = null;
    notifyListeners();
  }
}
