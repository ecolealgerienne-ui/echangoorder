import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

/// F02 — "PIN oublié". Aucun fournisseur SMS choisi (cf. status-V1.md) :
/// pas de réinitialisation en libre-service pour l'instant. La demande crée
/// une activité pour un modérateur back-office (même mécanisme que la
/// validation de compte, F00), qui recontacte le client par téléphone et
/// réinitialise son PIN depuis Odoo — plutôt que de laisser cet écran ne
/// rien faire du tout ("bientôt disponible" sans aucune action réelle).
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _requestSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final phoneError = validatePhone(_phoneController.text);
    if (phoneError != null) {
      AppMessenger.showError(context, phoneError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<OdooApiClient>().requestPinReset(phone: _phoneController.text.trim());
      if (mounted) setState(() => _requestSent = true);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _submit);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestSent) {
      return Scaffold(
        appBar: AppBar(title: Text('screens.ForgotPin.title'.tr())),
        body: SafeArea(
          child: ErrorStateView(
            icon: Icons.check_circle_outline,
            titleKey: 'auth.pinResetRequestSentTitle',
            messageKey: 'auth.pinResetRequestSentMessage',
            retryLabel: 'common.back'.tr(),
            onRetry: () => context.pop(),
          ),
        ),
      );
    }

    return ScreenPlaceholder(
      screenKey: 'ForgotPin',
      actions: [
        PlaceholderAction(label: () => 'actions.sendPinResetRequest'.tr(), onPressed: _submit),
        PlaceholderAction(
          label: () => 'common.back'.tr(),
          onPressed: () => context.pop(),
          variant: AppButtonVariant.secondary,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('auth.pinResetExplanation'.tr()),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'auth.phoneLabel'.tr(),
              hintText: '+213...',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
