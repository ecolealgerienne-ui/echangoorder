import 'package:flutter/material.dart';
import '../errors/app_messenger.dart';

/// Action non implémentable tant qu'Odoo n'est pas branché (ex: suppression de
/// compte, annulation effective). Affiche un message explicite plutôt qu'un
/// bouton silencieux, le temps de la phase "navigation sans données".
void showComingSoon(BuildContext context) {
  AppMessenger.showInfo(context, 'common.comingSoon');
}
