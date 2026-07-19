import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';

/// Vérifie qu'un compte réel (pas invité) est actif avant une action liée
/// au panier (F06+) — sinon propose l'inscription. Specs F02 : le mode
/// invité navigue librement, mais une vraie commande nécessite un compte
/// ("commande liée à un partner temporaire Odoo" pour les invités n'est
/// pas encore implémenté, cf. status-V1.md § Points de vigilance).
/// Retourne `true` si l'appelant peut continuer, `false` sinon.
Future<bool> requireAccount(BuildContext context) async {
  final status = context.read<AuthState>().status;
  if (status == SessionStatus.authenticated) return true;

  final signUp = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text('actions.signUpToOrder'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('actions.signUp'.tr()),
        ),
      ],
    ),
  );

  if (signUp == true && context.mounted) {
    context.push('/register/step1');
  }
  return false;
}
