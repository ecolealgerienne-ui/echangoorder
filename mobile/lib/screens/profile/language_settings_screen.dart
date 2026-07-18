import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return ScreenPlaceholder(
      screenKey: 'LanguageSettings',
      actions: [
        PlaceholderAction(
          label: 'Français',
          onPressed: () => context.setLocale(const Locale('fr')),
          variant: currentLocale.languageCode == 'fr' ? AppButtonVariant.primary : AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'العربية',
          onPressed: () => context.setLocale(const Locale('ar')),
          variant: currentLocale.languageCode == 'ar' ? AppButtonVariant.primary : AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
