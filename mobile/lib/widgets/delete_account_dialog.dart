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
  final api = context.read<OdooApiClient>();
  final authState = context.read<AuthState>();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _DeleteAccountDialogContent(api: api, authState: authState),
  );
}

/// Contenu du dialog, extrait en `StatefulWidget` dédié plutôt qu'un
/// `TextEditingController` créé dans la fonction top-level `showDeleteAccountDialog`
/// et disposé via `.whenComplete()` (même bug que `profile_screen.dart._editName` :
/// dispose trop tôt, pendant que le `TextField` est encore dans l'arbre le temps
/// de l'animation de fermeture du dialog — "A TextEditingController was used
/// after being disposed"). Un vrai `State.dispose()` est appelé par Flutter au
/// bon moment, une fois le widget réellement retiré.
class _DeleteAccountDialogContent extends StatefulWidget {
  final OdooApiClient api;
  final AuthState authState;

  const _DeleteAccountDialogContent({required this.api, required this.authState});

  @override
  State<_DeleteAccountDialogContent> createState() => _DeleteAccountDialogContentState();
}

class _DeleteAccountDialogContentState extends State<_DeleteAccountDialogContent> {
  final _pinController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.api.deleteAccount(pin: _pinController.text.trim());
      widget.api.clearSession();
      widget.authState.logout();
      if (mounted) Navigator.of(context).pop();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppMessenger.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('deleteAccount.title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'deleteAccount.body'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          PinInputField(
            controller: _pinController,
            labelKey: 'deleteAccount.pinLabel',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: _isSubmitting || validatePin(_pinController.text) != null ? null : _submit,
          child: Text(
            'deleteAccount.confirm'.tr(),
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}
