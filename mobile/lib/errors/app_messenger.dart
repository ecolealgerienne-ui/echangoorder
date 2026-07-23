import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_error.dart';

/// Point d'entrée UNIQUE pour afficher erreurs et messages sur les écrans.
/// Ne jamais appeler `ScaffoldMessenger`/`showDialog` directement ailleurs
/// pour ce genre de message — toujours passer par ces helpers, pour que
/// tout affichage (snackbar transitoire, dialog bloquant) soit cohérent
/// et que chaque message reste rattaché à une clé i18n traduisible.
class AppMessenger {
  AppMessenger._();

  /// Traduit un [AppError] avec repli sur `errors.unknown` si le code n'a
  /// pas encore d'entrée dans les fichiers de traduction.
  static String messageFor(AppError error) {
    final key = error.translationKey;
    final translated = key.tr();
    return translated == key ? 'errors.${AppError.unknown}'.tr() : translated;
  }

  /// Erreur transitoire (non bloquante) : snackbar rouge, avec bouton
  /// "Réessayer" optionnel (specs §4.4 : "retry automatique sur échec API" —
  /// ici le point d'accroche manuel une fois l'appel API réel branché).
  static void showError(BuildContext context, AppError error, {VoidCallback? onRetry}) {
    final tokens = AppColorTokens.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(messageFor(error)),
          backgroundColor: tokens.danger,
          action: onRetry != null
              ? SnackBarAction(label: 'actions.retry'.tr(), textColor: tokens.background, onPressed: onRetry)
              : null,
        ),
      );
  }

  /// Message informatif non-erreur (ex : "bientôt disponible", permission
  /// refusée). [messageKey] est une clé i18n complète (pas un code AppError).
  static void showInfo(BuildContext context, String messageKey) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messageKey.tr())));
  }

  /// Erreur bloquante : l'utilisateur doit accuser réception avant de
  /// continuer (ex : session expirée, erreur critique au checkout).
  static Future<void> showErrorDialog(BuildContext context, AppError error, {VoidCallback? onRetry}) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messageFor(error)),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              child: Text('actions.retry'.tr()),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );
  }
}
