import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

/// F10 — modification du PIN, vérifiée contre le PIN actuel côté serveur
/// (`/echango/profile/change_pin`, réutilise `res.users._check_pin`/
/// `_set_pin` de F02 — même délai anti brute-force sur le PIN actuel).
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
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

    _isSubmitting = true;
    try {
      await context.read<OdooApiClient>().changePin(
            currentPin: _currentController.text.trim(),
            newPin: _newController.text.trim(),
          );
      if (!mounted) return;
      AppMessenger.showInfo(context, 'profile.pinChanged');
      context.pop();
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _submit);
    } finally {
      _isSubmitting = false;
    }
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
