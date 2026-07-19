import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState authState, OdooApiClient api) async {
    if (_isSubmitting) return;
    final phone = authState.phone;
    if (phone == null) {
      authState.logout();
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
          PlaceholderAction(label: 'actions.logIn'.tr(), onPressed: () => _submit(authState, api)),
          PlaceholderAction(
            label: 'actions.logout'.tr(),
            onPressed: authState.logout,
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
              controller: TextEditingController(text: authState.phone ?? ''),
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
