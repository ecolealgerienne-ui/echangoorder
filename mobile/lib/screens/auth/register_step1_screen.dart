import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../errors/app_messenger.dart';
import '../../validation/validators.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final phoneError = validatePhone(_phoneController.text);
    if (phoneError != null) {
      AppMessenger.showError(context, phoneError);
      return;
    }
    // Nom, prénom, langue, CGU : écran encore à compléter (UI seulement,
    // pas de dépendance Odoo) — hors scope de cette passe.
    context.push('/register/step2', extra: _phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'RegisterStep1',
      actions: [
        PlaceholderAction(label: 'common.continue'.tr(), onPressed: _submit),
      ],
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'auth.phoneLabel'.tr(),
          hintText: '+213...',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
