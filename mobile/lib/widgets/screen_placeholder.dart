import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/locale_state.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class PlaceholderAction {
  // Fonction plutôt que `String` déjà résolue (bug trouvé par l'utilisateur,
  // 2026-07-20) : un appelant qui construit `'clé'.tr()` une fois dans SON
  // PROPRE build() fige le libellé au moment de la construction. En
  // différant l'appel à `.tr()` jusqu'au `build()` de `ScreenPlaceholder`
  // (voir plus bas), le libellé se recalcule au même endroit/moment que le
  // titre de l'écran — nécessaire mais pas suffisant à lui seul, voir
  // `context.watch<LocaleState>()` ci-dessous pour le reste du correctif.
  final String Function() label;
  final VoidCallback onPressed;
  final AppButtonVariant variant;

  const PlaceholderAction({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });
}

/// Écran générique utilisé pendant la phase "navigation sans données" :
/// chaque écran réel (F00-F17) utilise ce widget pour valider le parcours
/// avant d'être rempli avec sa propre UI + les appels Odoo.
class ScreenPlaceholder extends StatelessWidget {
  /// Clé dans assets/translations/*.json → `screens.` + [screenKey]
  final String screenKey;
  final List<PlaceholderAction> actions;
  final Widget? child;
  final bool showAppBar;
  final List<Widget>? appBarActions;

  const ScreenPlaceholder({
    super.key,
    required this.screenKey,
    this.actions = const [],
    this.child,
    this.showAppBar = true,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    // Force un rebuild au changement de langue (bug trouvé par
    // l'utilisateur, 2026-07-20) : les pages déjà montées dans la barre de
    // navigation à onglets ne se reconstruisent pas d'elles-mêmes sur un
    // simple `context.setLocale()` — voir `state/locale_state.dart`.
    context.watch<LocaleState>();

    return Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text('screens.$screenKey.title'.tr()), actions: appBarActions)
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showAppBar)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text('screens.$screenKey.title'.tr(), style: Theme.of(context).textTheme.titleLarge),
                ),
              if (child != null) child!,
              if (actions.isNotEmpty) const SizedBox(height: AppSpacing.lg),
              for (final action in actions)
                AppButton(label: action.label(), onPressed: action.onPressed, variant: action.variant),
            ],
          ),
        ),
      ),
    );
  }
}
