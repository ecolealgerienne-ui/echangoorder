import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_placeholder.dart';

/// F10 — localisation GPS du profil, stockée sur les champs standards
/// `res.partner.partner_latitude`/`partner_longitude` (module `base`, pas
/// besoin de `base_geolocalize` — voir CLAUDE.md § Principe architecture
/// Odoo). `permission_handler` gère le dialog d'explication + la demande
/// système (F14, déjà en place) ; `geolocator` ne sert qu'à lire la position
/// une fois la permission système accordée — pas de double demande, les
/// deux packages lisent la même permission OS.
class MyLocationScreen extends StatefulWidget {
  const MyLocationScreen({super.key});

  @override
  State<MyLocationScreen> createState() => _MyLocationScreenState();
}

class _MyLocationScreenState extends State<MyLocationScreen> {
  double? _latitude;
  double? _longitude;
  bool _isLoadingProfile = true;
  bool _isFetchingPosition = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await context.read<OdooApiClient>().getProfile();
      if (!mounted) return;
      setState(() {
        _latitude = (profile['latitude'] as num?)?.toDouble();
        _longitude = (profile['longitude'] as num?)?.toDouble();
        _isLoadingProfile = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
      AppMessenger.showError(context, e, onRetry: _loadProfile);
    }
  }

  Future<void> _useGpsLocation() async {
    if (_isFetchingPosition) return;
    final granted = await requestLocationPermission(context);
    if (!granted || !mounted) return;

    setState(() => _isFetchingPosition = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) AppMessenger.showError(context, const AppError(AppError.permissionDenied));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await context.read<OdooApiClient>().updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      AppMessenger.showInfo(context, 'myLocation.updated');
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _useGpsLocation);
    } catch (_) {
      if (mounted) AppMessenger.showError(context, const AppError(AppError.permissionDenied));
    } finally {
      if (mounted) setState(() => _isFetchingPosition = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

    return ScreenPlaceholder(
      screenKey: 'MyLocation',
      actions: [
        PlaceholderAction(
          label: 'actions.useGpsLocation'.tr(),
          onPressed: _useGpsLocation,
        ),
      ],
      child: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Text(
              hasLocation
                  ? '${'myLocation.currentLabel'.tr()}\n${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                  : 'myLocation.none'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
    );
  }
}
