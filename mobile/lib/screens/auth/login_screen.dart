import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_messenger.dart';
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
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit(AuthState authState) {
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
    // Vérification réelle des identifiants : F02 / Odoo. Ici, tout couple
    // téléphone/PIN au bon format ouvre la session (phase sans backend).
    authState.loginAsUser();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    return ScreenPlaceholder(
      screenKey: 'Login',
      actions: [
        PlaceholderAction(label: 'actions.logIn'.tr(), onPressed: () => _submit(authState)),
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
