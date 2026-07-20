import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_placeholder.dart';

/// F10/F11 — F11 (notifications push FCM) n'est pas encore branché, donc
/// aucune préférence à écrire côté Odoo pour l'instant : cet écran se
/// contente d'afficher/gérer la permission système (F14), qui conditionnera
/// l'envoi réel une fois F11 fait.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _requestOrOpenSettings() async {
    if (_status == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
    } else {
      await requestNotificationPermission(context);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isGranted = _status == PermissionStatus.granted;

    return ScreenPlaceholder(
      screenKey: 'NotificationSettings',
      actions: [
        if (_status != null && !isGranted)
          PlaceholderAction(
            label: () => (_status == PermissionStatus.permanentlyDenied
                    ? 'notificationSettings.openSettings'
                    : 'permissions.allow')
                .tr(),
            onPressed: _requestOrOpenSettings,
          ),
      ],
      child: _status == null
          ? const SizedBox.shrink()
          : Text(
              (isGranted ? 'notificationSettings.enabled' : 'notificationSettings.disabled').tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColorTokens.of(context).textMuted),
            ),
    );
  }
}
