import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../errors/app_error.dart';
import '../errors/app_messenger.dart';
import '../services/odoo_api_client.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../validation/validators.dart';
import 'pin_input_field.dart';

/// Popup de suppression de compte (specs F10) : avertissement + confirmation
/// par saisie du code PIN. Réutilise `res.users._check_pin` (F02) côté
/// serveur — `/echango/profile/delete_account` désactive le compte
/// (`active = false`, suppression logique standard Odoo, spec Expert Odoo)
/// puis l'app efface sa session locale ; le `redirect` de go_router (déjà
/// branché sur `AuthState`) renvoie alors vers les routes publiques.
/// **Confirmation par SMS après suppression (specs QA) hors scope** —
/// aucun fournisseur SMS choisi, voir status-V1.md.
Future<void> showDeleteAccountDialog(BuildContext context) {
  final pinController = TextEditingController();
  final api = context.read<OdooApiClient>();
  final authState = context.read<AuthState>();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var isSubmitting = false;

      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> submit() async {
            setState(() => isSubmitting = true);
            try {
              await api.deleteAccount(pin: pinController.text.trim());
              api.clearSession();
              authState.logout();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } on AppError catch (e) {
              setState(() => isSubmitting = false);
              if (dialogContext.mounted) AppMessenger.showError(dialogContext, e);
            }
          }

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
                PinInputField(
                  controller: pinController,
                  labelKey: 'deleteAccount.pinLabel',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: isSubmitting || validatePin(pinController.text) != null ? null : submit,
                child: Text(
                  'deleteAccount.confirm'.tr(),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
