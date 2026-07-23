import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';

/// F10 — adresses de livraison sauvegardées : contacts enfants standards de
/// `res.partner` (`type = 'delivery'`), pas un modèle custom (cf. CLAUDE.md
/// § Principe architecture Odoo). `res.partner` étant en lecture seule pour
/// le portail, tout le CRUD passe par `controllers/profile_controller.py`
/// en `sudo()` avec vérification explicite de `parent_id`.
///
/// L'ancien menu séparé "Ma localisation" est fusionné ici : chaque adresse
/// peut optionnellement être enrichie de coordonnées GPS (`partner_latitude`/
/// `partner_longitude`, champs standards déjà utilisés pour F10) en plus de
/// la saisie manuelle — pas à sa place, faute de service de géocodage
/// inverse choisi (impossible de déduire rue/ville/code postal depuis des
/// coordonnées seules). La vérification de zone de livraison (F07) continue
/// de se baser sur ville/code postal, pas sur les coordonnées.
///
/// Ces adresses sont proposées au choix dans le checkout (F07,
/// `CheckoutAddressScreen`) — favorite pré-sélectionnée, avec une option
/// "nouvelle adresse" qui retombe sur un formulaire libre pour une adresse
/// ponctuelle non sauvegardée.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  Future<List<Map<String, dynamic>>>? _addressesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _addressesFuture = context.read<OdooApiClient>().listAddresses();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? address}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _AddressFormScreen(address: address)),
    );
    if (saved == true) _load();
  }

  Future<void> _remove(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('addresses.deleteConfirmTitle'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('common.cancel'.tr())),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('common.delete'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<OdooApiClient>().removeAddress(addressId: address['id'] as int);
      if (!mounted) return;
      AppMessenger.showInfo(context, 'addresses.removed');
      _load();
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.Addresses.title'.tr())),
      body: SafeArea(
        child: _addressesFuture == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _addressesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error is AppError
                        ? snapshot.error as AppError
                        : const AppError(AppError.unknown);
                    return ErrorStateView.forError(error, onRetry: _load);
                  }
                  final addresses = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: addresses.isEmpty
                              ? const ErrorStateView(
                                  icon: Icons.location_on_outlined,
                                  titleKey: 'addresses.emptyTitle',
                                  messageKey: 'addresses.emptyMessage',
                                )
                              : ListView.separated(
                                  itemCount: addresses.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (context, index) => _AddressCard(
                                    address: addresses[index],
                                    onTap: () => _openForm(address: addresses[index]),
                                    onDelete: () => _remove(addresses[index]),
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(label: 'addresses.addTitle'.tr(), onPressed: () => _openForm()),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AddressCard({required this.address, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = address['name'] as String? ?? '';
    final street = address['street'] as String? ?? '';
    final city = address['city'] as String? ?? '';
    final zip = address['zip'] as String? ?? '';
    final isFavorite = address['favorite'] as bool? ?? false;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(isFavorite ? Icons.star : Icons.location_on_outlined),
        title: Text(name),
        subtitle: Text('$street, $zip $city'.trim()),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'common.delete'.tr(),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address;

  const _AddressFormScreen({this.address});

  @override
  State<_AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<_AddressFormScreen> {
  late final _nameController = TextEditingController(text: widget.address?['name'] as String? ?? '');
  late final _streetController = TextEditingController(text: widget.address?['street'] as String? ?? '');
  late final _cityController = TextEditingController(text: widget.address?['city'] as String? ?? '');
  late final _zipController = TextEditingController(text: widget.address?['zip'] as String? ?? '');
  late final _commentController = TextEditingController(text: widget.address?['comment'] as String? ?? '');
  late bool _favorite = widget.address?['favorite'] as bool? ?? false;
  // `partner_latitude`/`partner_longitude` valent 0.0 par défaut côté Odoo
  // (champs Float, jamais null) — traité comme "pas de position" ici,
  // aucune adresse de livraison réelle n'étant à l'équateur.
  late double? _latitude = _nonZero(widget.address?['latitude']);
  late double? _longitude = _nonZero(widget.address?['longitude']);
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  static double? _nonZero(dynamic value) {
    final v = (value as num?)?.toDouble();
    return (v == null || v == 0.0) ? null : v;
  }

  Future<void> _useGpsLocation() async {
    if (_isFetchingLocation) return;
    final granted = await requestLocationPermission(context);
    if (!granted || !mounted) return;

    setState(() => _isFetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) AppMessenger.showError(context, const AppError(AppError.permissionDenied));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      if (mounted) AppMessenger.showError(context, const AppError(AppError.permissionDenied));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final streetError = validateRequired(_streetController.text);
    final cityError = validateRequired(_cityController.text);
    final error = streetError ?? cityError;
    if (error != null) {
      AppMessenger.showError(context, error);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = context.read<OdooApiClient>();
      final existingId = widget.address?['id'] as int?;
      if (existingId != null) {
        await api.updateAddress(
          addressId: existingId,
          name: _nameController.text.trim(),
          street: _streetController.text.trim(),
          city: _cityController.text.trim(),
          zipCode: _zipController.text.trim(),
          comment: _commentController.text.trim(),
          favorite: _favorite,
          latitude: _latitude,
          longitude: _longitude,
        );
      } else {
        await api.addAddress(
          name: _nameController.text.trim(),
          street: _streetController.text.trim(),
          city: _cityController.text.trim(),
          zipCode: _zipController.text.trim(),
          comment: _commentController.text.trim(),
          favorite: _favorite,
          latitude: _latitude,
          longitude: _longitude,
        );
      }
      if (!mounted) return;
      AppMessenger.showInfo(context, existingId != null ? 'addresses.updated' : 'addresses.added');
      Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _submit);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;
    return Scaffold(
      appBar: AppBar(title: Text((isEditing ? 'addresses.editTitle' : 'addresses.addTitle').tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'addresses.nameLabel'.tr(), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.md),
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
                controller: _commentController,
                decoration: InputDecoration(labelText: 'checkout.notesLabel'.tr(), border: const OutlineInputBorder()),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value ?? false),
                title: Text('addresses.favoriteLabel'.tr()),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'actions.useGpsLocation'.tr(),
                onPressed: _useGpsLocation,
                variant: AppButtonVariant.secondary,
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '📍 ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColorTokens.of(context).textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'common.confirm'.tr(), onPressed: _isSubmitting ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
