import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/logout.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

/// Session expirée (24h d'inactivité ou rejet serveur, cf.
/// `AuthState.expireSession`) : redemande uniquement le PIN, le téléphone
/// étant déjà connu de l'appareil — contrairement à `LoginScreen` qui
/// redemande les deux. Le `redirect` de go_router impose cet écran tant que
/// `AuthState.isSessionExpired` est vrai (voir `navigation/app_router.dart`).
class ReauthPinScreen extends StatefulWidget {
  const ReauthPinScreen({super.key});

  @override
  State<ReauthPinScreen> createState() => _ReauthPinScreenState();
}

class _ReauthPinScreenState extends State<ReauthPinScreen> {
  final _pinController = TextEditingController();
  // Champ téléphone en lecture seule (juste affiché, jamais modifié) :
  // remonté en champ de State plutôt que recréé à chaque build() — un
  // TextEditingController instancié directement dans build() n'est jamais
  // disposé (fuite trouvée à l'audit technique du 2026-07-19, aggravée
  // ici par les tentatives de PIN échouées qui redéclenchent un build).
  late final _phoneDisplayController = TextEditingController(text: context.read<AuthState>().phone ?? '');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _phoneDisplayController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState authState, OdooApiClient api) async {
    if (_isSubmitting) return;
    final phone = authState.phone;
    if (phone == null) {
      fullLogout(context);
      return;
    }
    final pinError = validatePin(_pinController.text);
    if (pinError != null) {
      AppMessenger.showError(context, pinError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await api.login(phone: phone, pin: _pinController.text.trim());
      authState.loginAsUser(phone: phone);
    } on AppError catch (error) {
      if (!mounted) return;
      AppMessenger.showError(context, error, onRetry: () => _submit(authState, api));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();
    final api = context.read<OdooApiClient>();

    return PopScope(
      canPop: false,
      child: ScreenPlaceholder(
        screenKey: 'Reauth',
        actions: [
          PlaceholderAction(label: () => 'actions.logIn'.tr(), onPressed: () => _submit(authState, api)),
          PlaceholderAction(
            label: () => 'actions.logout'.tr(),
            onPressed: () => fullLogout(context),
            variant: AppButtonVariant.secondary,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('errors.auth.session_expired'.tr()),
            const SizedBox(height: AppSpacing.md),
            TextField(
              enabled: false,
              controller: _phoneDisplayController,
              decoration: InputDecoration(labelText: 'auth.phoneLabel'.tr(), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.md),
            PinInputField(controller: _pinController, labelKey: 'auth.pinLabel'),
          ],
        ),
      ),
    );
  }
}
