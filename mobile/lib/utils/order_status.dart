import 'package:easy_localization/easy_localization.dart';

/// F08 — libellé du statut de préparation/livraison, réutilisé par
/// l'historique (`OrderHistoryScreen`) et le suivi (`OrderTrackingScreen`).
/// `null` si le serveur n'a pas pu résoudre de `stock.picking` pour cette
/// commande (produit non suivi en stock, etc. — voir `order_controller.py.
/// _prep_status`) : les écrans appelants retombent alors sur le libellé
/// générique "Confirmée".
///
/// Décision produit 2026-07 (voir CLAUDE.md § Statuts de commande) : pour
/// une livraison à domicile, un `stock.picking` validé (`prep_status ==
/// 'completed'`) ne veut pas encore dire "livrée" — juste que le colis est
/// prêt/emballé, en attente du transporteur. Le vrai passage à "livrée" est
/// piloté par `x_delivery_status` (statut déclaré manuellement en
/// back-office, aucun équivalent standard sans intégration transport
/// réelle — hors périmètre Phase 1), qui prend le pas sur `prep_status`
/// une fois renseigné.
String? prepStatusLabel(Map<String, dynamic> order) {
  final isPickup = order['x_reception_mode'] == 'pickup';
  final prepStatus = order['prep_status'] as String?;

  if (!isPickup) {
    switch (order['x_delivery_status'] as String?) {
      case 'out_for_delivery':
        return 'order.outForDelivery'.tr();
      case 'delivered':
        return 'order.delivered'.tr();
    }
  }

  switch (prepStatus) {
    case 'pending':
      return 'order.prepPending'.tr();
    // "En cours de préparation" (décision produit 2026-07) : la réservation
    // de stock reste automatique à la confirmation (pour éviter les
    // commandes annulées faute de stock), donc le picking passe "prêt"
    // (assigné) quasi instantanément — ça ne dit rien sur si un opérateur a
    // commencé à traiter la commande. `in_progress` (voir order_controller.
    // py._prep_status, basé sur stock.picking.user_id — champ standard
    // "Responsable") comble ce vrai palier intermédiaire, sans champ custom.
    case 'in_progress':
      return 'order.prepInProgress'.tr();
    case 'completed':
      // Retrait magasin : le picking validé = le client a déjà récupéré sa
      // commande, statut terminal. Livraison à domicile : le colis est
      // prêt/emballé mais pas encore parti — voir x_delivery_status
      // ci-dessus pour la suite (en cours de livraison / livrée).
      return (isPickup ? 'order.prepCompletedPickup' : 'order.prepReadyDelivery').tr();
    default:
      return null;
  }
}
