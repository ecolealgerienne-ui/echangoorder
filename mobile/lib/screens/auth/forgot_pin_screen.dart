import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../errors/app_messenger.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/pin_input_field.dart';
import '../../widgets/screen_placeholder.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _newPinController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  void _requestSms() {
    final phoneError = validatePhone(_phoneController.text);
    if (phoneError != null) {
      AppMessenger.showError(context, phoneError);
      return;
    }
    // Envoi SMS réel : F02 / Odoo (provider type Twilio).
    showComingSoon(context);
  }

  void _confirmNewPin() {
    final codeError = validateRequired(_smsCodeController.text);
    if (codeError != null) {
      AppMessenger.showError(context, codeError);
      return;
    }
    final pinError = validatePin(_newPinController.text);
    if (pinError != null) {
      AppMessenger.showError(context, pinError);
      return;
    }
    showComingSoon(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'ForgotPin',
      actions: [
        PlaceholderAction(label: 'actions.receiveSms'.tr(), onPressed: _requestSms),
        PlaceholderAction(label: 'common.confirm'.tr(), onPressed: _confirmNewPin),
        PlaceholderAction(
          label: 'common.back'.tr(),
          onPressed: () => context.pop(),
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
          TextField(
            controller: _smsCodeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'auth.smsCodeLabel'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PinInputField(controller: _newPinController, labelKey: 'auth.newPinLabel'),
        ],
      ),
    );
  }
}
