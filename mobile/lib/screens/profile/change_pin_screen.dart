import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../errors/app_messenger.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../validation/validators.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final currentError = validatePin(_currentController.text);
    if (currentError != null) {
      AppMessenger.showError(context, currentError);
      return;
    }
    final newError = validatePin(_newController.text);
    if (newError != null) {
      AppMessenger.showError(context, newError);
      return;
    }
    final matchError = validatePinMatch(_newController.text, _confirmController.text);
    if (matchError != null) {
      AppMessenger.showError(context, matchError);
      return;
    }
    // Vérification du PIN actuel + écriture du nouveau : F02 / Odoo.
    showComingSoon(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'ChangePin',
      actions: [
        PlaceholderAction(label: 'common.confirm'.tr(), onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(controller: _currentController, labelKey: 'auth.currentPinLabel'),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _newController, labelKey: 'auth.newPinLabel'),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _confirmController, labelKey: 'auth.pinConfirmLabel'),
        ],
      ),
    );
  }
}
