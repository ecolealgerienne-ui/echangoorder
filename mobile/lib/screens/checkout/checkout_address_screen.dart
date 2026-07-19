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

  @override
  void initState() {
    super.initState();
    final checkout = context.read<CheckoutState>();
    _streetController.text = checkout.street;
    _cityController.text = checkout.city;
    _zipController.text = checkout.zipCode;
    _notesController.text = checkout.notes;
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
    if (context.mounted) AppMessenger.showInfo(context, 'common.comingSoon');
  }

  Future<void> _continue() async {
    if (_isChecking) return;
    final streetError = validateRequired(_streetController.text);
    final cityError = validateRequired(_cityController.text);
    final zipError = validateRequired(_zipController.text);
    final error = streetError ?? cityError ?? zipError;
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }

    setState(() => _isChecking = true);
    try {
      final covered = await context.read<OdooApiClient>().checkDeliveryZone(
            city: _cityController.text.trim(),
            zipCode: _zipController.text.trim(),
          );
      if (!mounted) return;
      context.read<CheckoutState>().setAddress(
            street: _streetController.text.trim(),
            city: _cityController.text.trim(),
            zipCode: _zipController.text.trim(),
            notes: _notesController.text.trim(),
          );
      if (covered) {
        context.push('/cart/checkout/timeslot');
      } else {
        context.push('/cart/checkout/out-of-zone');
      }
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _continue);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.CheckoutAddress.title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
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
              AppButton(
                label: 'common.continue'.tr(),
                onPressed: _isChecking ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
