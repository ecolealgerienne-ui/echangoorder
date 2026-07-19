import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';

/// F10 — adresses de livraison sauvegardées : contacts enfants standards de
/// `res.partner` (`type = 'delivery'`), pas un modèle custom (cf. CLAUDE.md
/// § Principe architecture Odoo). `res.partner` étant en lecture seule pour
/// le portail, tout le CRUD passe par `controllers/profile_controller.py`
/// en `sudo()` avec vérification explicite de `parent_id`.
///
/// **Non fait dans cette passe** : le checkout (F07) ne propose pas encore
/// de choisir une de ces adresses sauvegardées — il continue de créer un
/// contact `delivery` ad hoc à chaque confirmation (voir
/// `checkout_controller.py`). Réutiliser une adresse sauvegardée au
/// checkout est un point de vigilance à traiter séparément.
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
  bool _isSubmitting = false;

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
        );
      } else {
        await api.addAddress(
          name: _nameController.text.trim(),
          street: _streetController.text.trim(),
          city: _cityController.text.trim(),
          zipCode: _zipController.text.trim(),
          comment: _commentController.text.trim(),
          favorite: _favorite,
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
              AppButton(label: 'common.confirm'.tr(), onPressed: _isSubmitting ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
