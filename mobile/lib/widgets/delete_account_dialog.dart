import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/coming_soon.dart';

/// Popup de suppression de compte (specs F10) : avertissement +
/// confirmation par saisie du code PIN, en un seul dialog comme dans le
/// wireframe. La validation réelle du PIN nécessitera Odoo (F02) ; pour
/// l'instant toute saisie à 4 chiffres déclenche le message "à venir".
Future<void> showDeleteAccountDialog(BuildContext context) {
  final pinController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        return AlertDialog(
          title: Text('deleteAccount.title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'deleteAccount.body'.tr(),
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('deleteAccount.pinLabel'.tr(), style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: pinController.text.length == 4
                  ? () {
                      Navigator.of(dialogContext).pop();
                      showComingSoon(context);
                    }
                  : null,
              child: Text(
                'deleteAccount.confirm'.tr(),
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    ),
  );
}
