import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../errors/app_error.dart';
import '../errors/app_messenger.dart';

/// Affiche l'explication AVANT toute demande de permission système
/// (specs F14 : "Explication affichée AVANT la demande de permission système"),
/// puis déclenche la demande native seulement si l'utilisateur clique
/// "Autoriser". Un refus n'empêche jamais l'utilisation de l'app.
Future<bool> requestPermissionWithExplanation(
  BuildContext context, {
  required Permission permission,
  required String titleKey,
  required String bodyKey,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titleKey.tr()),
      content: Text(bodyKey.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('permissions.notNow'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('permissions.allow'.tr()),
        ),
      ],
    ),
  );

  if (agreed != true || !context.mounted) return false;

  final status = await permission.request();
  if (!status.isGranted && context.mounted) {
    AppMessenger.showError(context, const AppError(AppError.permissionDenied));
  }
  return status.isGranted;
}

Future<bool> requestLocationPermission(BuildContext context) => requestPermissionWithExplanation(
      context,
      permission: Permission.location,
      titleKey: 'permissions.locationTitle',
      bodyKey: 'permissions.locationBody',
    );

Future<bool> requestNotificationPermission(BuildContext context) => requestPermissionWithExplanation(
      context,
      permission: Permission.notification,
      titleKey: 'permissions.notificationTitle',
      bodyKey: 'permissions.notificationBody',
    );
