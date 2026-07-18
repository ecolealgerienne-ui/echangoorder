import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class PlaceholderAction {
  final String label;
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
  /// Clé dans assets/translations/*.json → screens.<screenKey>
  final String screenKey;
  final List<PlaceholderAction> actions;
  final Widget? child;
  final bool showAppBar;

  const ScreenPlaceholder({
    super.key,
    required this.screenKey,
    this.actions = const [],
    this.child,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text('screens.$screenKey.title'.tr())) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showAppBar)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('screens.$screenKey.title'.tr(), style: Theme.of(context).textTheme.titleLarge),
                ),
              Text(
                'screens.$screenKey.subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              if (child != null) ...[
                const SizedBox(height: AppSpacing.lg),
                child!,
              ],
              if (actions.isNotEmpty) const SizedBox(height: AppSpacing.lg),
              for (final action in actions)
                AppButton(label: action.label, onPressed: action.onPressed, variant: action.variant),
            ],
          ),
        ),
      ),
    );
  }
}
