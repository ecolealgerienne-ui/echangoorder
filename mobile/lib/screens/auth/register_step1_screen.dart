import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../errors/app_messenger.dart';
import '../../theme/app_theme.dart';
import '../../validation/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

/// Odoo `res.lang` (module `base`) attend un code complet (`fr_FR`,
/// `ar_001`...), pas juste `fr`/`ar` — `ar_001` est le code Odoo standard
/// pour "Arabic / العربية" (langue générique, pas liée à un pays). Si ce
/// code n'est pas installé sur l'instance cible, le contrôleur
/// `/echango/auth/register` retombe silencieusement sur `lang=False`
/// (voir `controllers/auth_controller.py`) — sans effet de bord.
const _odooLangByLocale = {'fr': 'fr_FR', 'ar': 'ar_001'};

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _selectedLocale = context.locale.languageCode;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final nameError = validateRequired(_nameController.text);
    if (nameError != null) {
      AppMessenger.showError(context, nameError);
      return;
    }
    final phoneError = validatePhone(_phoneController.text);
    if (phoneError != null) {
      AppMessenger.showError(context, phoneError);
      return;
    }
    context.push('/register/step2', extra: {
      'phone': _phoneController.text.trim(),
      'name': _nameController.text.trim(),
      'lang': _odooLangByLocale[_selectedLocale] ?? _odooLangByLocale['fr']!,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'RegisterStep1',
      actions: [
        PlaceholderAction(label: 'common.continue'.tr(), onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'auth.nameLabel'.tr(), border: const OutlineInputBorder()),
          ),
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
          const SizedBox(height: AppSpacing.md),
          Text('auth.languageLabel'.tr(), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Français',
                  onPressed: () => setState(() => _selectedLocale = 'fr'),
                  variant: _selectedLocale == 'fr' ? AppButtonVariant.primary : AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'العربية',
                  onPressed: () => setState(() => _selectedLocale = 'ar'),
                  variant: _selectedLocale == 'ar' ? AppButtonVariant.primary : AppButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
