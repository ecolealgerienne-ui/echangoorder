import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep3Screen extends StatefulWidget {
  final String phone;

  const RegisterStep3Screen({super.key, required this.phone});

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState authState, OdooApiClient api) async {
    if (_isSubmitting) return;
    final pinError = validatePin(_pinController.text);
    if (pinError != null) {
      AppMessenger.showError(context, pinError);
      return;
    }
    final matchError = validatePinMatch(_pinController.text, _confirmController.text);
    if (matchError != null) {
      AppMessenger.showError(context, matchError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final pin = _pinController.text.trim();
      await api.register(phone: widget.phone, pin: pin);
      await api.login(phone: widget.phone, pin: pin);
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
      screenKey: 'RegisterStep3',
      actions: [
        PlaceholderAction(label: 'common.confirm'.tr(), onPressed: () => _submit(authState, api)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(controller: _pinController, labelKey: 'auth.pinLabel'),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _confirmController, labelKey: 'auth.pinConfirmLabel'),
          const SizedBox(height: AppSpacing.md),
          // F13 — CGU/confidentialité accessibles depuis l'inscription
          // (specs QA), sans bloquer la création de compte sur une case à
          // cocher (non demandé explicitement par les specs).
          Text('auth.termsNotice'.tr(), style: Theme.of(context).textTheme.bodySmall),
          Wrap(
            children: [
              TextButton(onPressed: () => context.push('/legal/cgu'), child: Text('legal.cgu'.tr())),
              TextButton(onPressed: () => context.push('/legal/privacy'), child: Text('legal.privacy'.tr())),
            ],
          ),
        ],
      ),
    );
  }
}
