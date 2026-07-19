import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Valeurs par défaut pratiques pour les tests locaux — uniquement en
  // mode debug, jamais dans un build de release.
  final _phoneController = TextEditingController(text: kDebugMode ? '+213555545352' : null);
  final _pinController = TextEditingController(text: kDebugMode ? '010203' : null);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState authState, OdooApiClient api) async {
    if (_isSubmitting) return;
    final phoneError = validatePhone(_phoneController.text);
    if (phoneError != null) {
      AppMessenger.showError(context, phoneError);
      return;
    }
    final pinError = validatePin(_pinController.text);
    if (pinError != null) {
      AppMessenger.showError(context, pinError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await api.login(phone: _phoneController.text.trim(), pin: _pinController.text.trim());
      authState.loginAsUser();
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

    return ScreenPlaceholder(
      screenKey: 'Login',
      actions: [
        PlaceholderAction(label: 'actions.logIn'.tr(), onPressed: () => _submit(authState, api)),
        PlaceholderAction(
          label: 'actions.forgotPin'.tr(),
          onPressed: () => context.push('/forgot-pin'),
          variant: AppButtonVariant.secondary,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'auth.phoneLabel'.tr(),
              hintText: '+213...',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _pinController, labelKey: 'auth.pinLabel'),
        ],
      ),
    );
  }
}
