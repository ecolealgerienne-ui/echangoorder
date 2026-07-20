import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/locale_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  /// `context.setLocale()` (easy_localization) ne suffit pas à lui seul à
  /// rafraîchir les pages déjà montées dans la barre de navigation à
  /// onglets (bug trouvé par l'utilisateur, 2026-07-20 — voir
  /// `state/locale_state.dart`) : on déclenche `LocaleState` en plus, une
  /// fois la nouvelle langue effectivement chargée.
  Future<void> _changeLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    if (!context.mounted) return;
    context.read<LocaleState>().notifyLocaleChanged();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return ScreenPlaceholder(
      screenKey: 'LanguageSettings',
      actions: [
        PlaceholderAction(
          label: () => 'Français',
          onPressed: () => _changeLocale(context, const Locale('fr')),
          variant: currentLocale.languageCode == 'fr' ? AppButtonVariant.primary : AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: () => 'العربية',
          onPressed: () => _changeLocale(context, const Locale('ar')),
          variant: currentLocale.languageCode == 'ar' ? AppButtonVariant.primary : AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
