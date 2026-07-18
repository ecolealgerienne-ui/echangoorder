import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../errors/app_messenger.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep3Screen extends StatefulWidget {
  const RegisterStep3Screen({super.key});

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit(AuthState authState) {
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
    authState.loginAsUser();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    return ScreenPlaceholder(
      screenKey: 'RegisterStep3',
      actions: [
        PlaceholderAction(label: 'common.confirm'.tr(), onPressed: () => _submit(authState)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(controller: _pinController, labelKey: 'auth.pinLabel'),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _confirmController, labelKey: 'auth.pinConfirmLabel'),
        ],
      ),
    );
  }
}
