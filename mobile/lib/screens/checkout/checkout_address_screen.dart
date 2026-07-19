import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../services/permission_service.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';

/// F07 — étape 2 (si livraison) : adresse + vérification de zone
/// (`x_delivery_zone`, contrôleur dédié — voir CLAUDE.md § Principe
/// architecture Odoo).
///
/// Propose de choisir une adresse sauvegardée (F10, favorite
/// pré-sélectionnée) plutôt que de tout ressaisir à chaque commande — point
/// de vigilance résolu, voir status-V1.md. `checkout_controller.py.confirm`
/// réutilise directement le contact existant (`address_id`) au lieu d'en
/// créer un nouveau ; le formulaire libre reste disponible ("nouvelle
/// adresse") pour une adresse ponctuelle non sauvegardée.
class CheckoutAddressScreen extends StatefulWidget {
  const CheckoutAddressScreen({super.key});

  @override
  State<CheckoutAddressScreen> createState() => _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends State<CheckoutAddressScreen> {
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isChecking = false;

  // null = en cours de chargement. Un échec de chargement (réseau...) est
  // signalé via AppMessenger (voir _load) puis traité comme une liste vide
  // — l'utilisateur peut toujours continuer avec le formulaire "nouvelle
  // adresse" plutôt que de bloquer tout le checkout sur cette erreur.
  List<Map<String, dynamic>>? _addresses;
  // null = formulaire "nouvelle adresse" ; sinon id d'une adresse
  // sauvegardée sélectionnée.
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    final checkout = context.read<CheckoutState>();
    _streetController.text = checkout.street;
    _cityController.text = checkout.city;
    _zipController.text = checkout.zipCode;
    _notesController.text = checkout.notes;
    // Sélection déjà faite lors d'une visite précédente de cet écran dans
    // le même parcours (ex. retour en arrière depuis l'étape suivante) :
    // sert aussi de signal "premier passage" pour la pré-sélection
    // automatique ci-dessous.
    final alreadyVisited = checkout.addressId != null || checkout.street.isNotEmpty;
    _selectedAddressId = checkout.addressId;
    _load(autoSelect: !alreadyVisited);
  }

  Future<void> _load({required bool autoSelect}) async {
    setState(() => _addresses = null);
    try {
      final addresses = await context.read<OdooApiClient>().listAddresses();
      if (!mounted) return;
      setState(() => _addresses = addresses);
      if (autoSelect && addresses.isNotEmpty) {
        // Pré-sélection : adresse favorite, sinon la première.
        final favorite = addresses.firstWhere(
          (a) => a['favorite'] == true,
          orElse: () => addresses.first,
        );
        setState(() => _selectedAddressId = favorite['id'] as int);
      }
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _addresses = const []);
      AppMessenger.showError(context, e, onRetry: () => _load(autoSelect: autoSelect));
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _useGpsLocation() async {
    await requestLocationPermission(context);
    // Pré-remplissage réel (géocodage inverse) : nécessite un service
    // externe (Google/Mapbox/Nominatim) + package geolocator, décision non
    // prise pour l'instant — voir status-V1.md. On exerce quand même la
    // demande de permission (F14).
    if (mounted) AppMessenger.showInfo(context, 'common.comingSoon');
  }

  Future<void> _continue(List<Map<String, dynamic>> addresses) async {
    if (_isChecking) return;

    String street, city, zip, notes;
    int? addressId;
    if (_selectedAddressId != null) {
      final address = addresses.firstWhere((a) => a['id'] == _selectedAddressId);
      addressId = address['id'] as int;
      street = address['street'] as String? ?? '';
      city = address['city'] as String? ?? '';
      zip = address['zip'] as String? ?? '';
      notes = address['comment'] as String? ?? '';
    } else {
      final streetError = validateRequired(_streetController.text);
      final cityError = validateRequired(_cityController.text);
      final zipError = validateRequired(_zipController.text);
      final error = streetError ?? cityError ?? zipError;
      if (error != null) {
        AppMessenger.showError(context, error);
        return;
      }
      street = _streetController.text.trim();
      city = _cityController.text.trim();
      zip = _zipController.text.trim();
      notes = _notesController.text.trim();
    }

    setState(() => _isChecking = true);
    try {
      final covered = await context.read<OdooApiClient>().checkDeliveryZone(city: city, zipCode: zip);
      if (!mounted) return;
      context.read<CheckoutState>().setAddress(
            street: street,
            city: city,
            zipCode: zip,
            notes: notes,
            addressId: addressId,
          );
      if (covered) {
        context.push('/cart/checkout/timeslot');
      } else {
        context.push('/cart/checkout/out-of-zone');
      }
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: () => _continue(addresses));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Widget _manualForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _streetController,
          decoration: InputDecoration(labelText: 'checkout.streetLabel'.tr(), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _cityController,
          decoration: InputDecoration(labelText: 'checkout.cityLabel'.tr(), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _zipController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'checkout.zipLabel'.tr(), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: 'checkout.notesLabel'.tr(), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'actions.useGpsLocation'.tr(),
          onPressed: _useGpsLocation,
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }

  Widget _addressChoice(Map<String, dynamic> address) {
    final id = address['id'] as int;
    final name = address['name'] as String? ?? '';
    final street = address['street'] as String? ?? '';
    final city = address['city'] as String? ?? '';
    final zip = address['zip'] as String? ?? '';
    final isFavorite = address['favorite'] as bool? ?? false;
    return RadioListTile<int?>(
      value: id,
      title: Text(isFavorite ? '⭐ $name' : name),
      subtitle: Text('$street, $zip $city'.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.CheckoutAddress.title'.tr())),
      body: SafeArea(
        child: _addresses == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                // RadioGroup centralise groupValue/onChanged pour tous les
                // Radio descendants (individuels dépréciés depuis Flutter
                // 3.32, cf. CheckoutTimeslotScreen).
                child: RadioGroup<int?>(
                  groupValue: _selectedAddressId,
                  onChanged: (value) => setState(() => _selectedAddressId = value),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final address in _addresses!) _addressChoice(address),
                      if (_addresses!.isNotEmpty)
                        RadioListTile<int?>(value: null, title: Text('addresses.addTitle'.tr())),
                      if (_addresses!.isNotEmpty) const SizedBox(height: AppSpacing.md),
                      if (_selectedAddressId == null) _manualForm(),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'common.continue'.tr(),
                        onPressed: _isChecking ? null : () => _continue(_addresses!),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
