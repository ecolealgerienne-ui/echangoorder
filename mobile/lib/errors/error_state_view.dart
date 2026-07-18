import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'app_error.dart';
import 'app_messenger.dart';

/// État plein écran réutilisable : erreurs bloquantes (maintenance, serveur
/// injoignable) ET états vides (panier vide, aucune commande, aucun
/// résultat — cf. specs UX §"définir les états vides pour chaque écran").
/// Un seul widget pour garder un rendu cohérent partout dans l'app.
class ErrorStateView extends StatelessWidget {
  final IconData icon;
  final String titleKey;

  /// Clé i18n à traduire (mutuellement exclusif avec [message]).
  final String? messageKey;

  /// Message déjà résolu (ex : sortie de [AppMessenger.messageFor]).
  final String? message;

  final String? retryLabel;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    required this.icon,
    required this.titleKey,
    this.messageKey,
    this.message,
    this.retryLabel,
    this.onRetry,
  });

  /// Construit l'état à partir d'un [AppError] : titre générique, message
  /// déjà traduit via [AppMessenger] (avec repli sur `errors.unknown`).
  factory ErrorStateView.forError(AppError error, {VoidCallback? onRetry}) {
    return ErrorStateView(
      icon: Icons.error_outline,
      titleKey: 'errors.title',
      message: AppMessenger.messageFor(error),
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message ?? messageKey?.tr();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              titleKey.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (resolvedMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                resolvedMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: retryLabel ?? 'actions.retry'.tr(), onPressed: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
