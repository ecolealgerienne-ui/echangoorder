import 'package:easy_localization/easy_localization.dart';

/// F08 — libellé du statut de préparation/livraison, réutilisé par
/// l'historique (`OrderHistoryScreen`) et le suivi (`OrderTrackingScreen`).
/// `null` si le serveur n'a pas pu résoudre de `stock.picking` pour cette
/// commande (produit non suivi en stock, etc. — voir `order_controller.py.
/// _prep_status`) : les écrans appelants retombent alors sur le libellé
/// générique "Confirmée".
///
/// Décision produit 2026-07 (voir CLAUDE.md § Statuts de commande) : un
/// `stock.picking` validé (`prep_status == 'completed'`) ne veut pas encore
/// dire "remise au client" côté livraison à domicile ni côté retrait
/// magasin — juste que l'opérateur a fini de préparer. Le vrai passage à
/// "livrée"/"récupérée" est piloté par un statut déclaré manuellement en
/// back-office (`x_delivery_status`/`x_pickup_collected`, aucun équivalent
/// standard sans un vrai système de pointage/transport — hors périmètre
/// Phase 1), qui prend le pas sur `prep_status` une fois renseigné.
String? prepStatusLabel(Map<String, dynamic> order) {
  final isPickup = order['x_reception_mode'] == 'pickup';
  final prepStatus = order['prep_status'] as String?;

  if (prepStatus == 'completed') {
    if (isPickup) {
      // F08 — signalé par l'utilisateur en test réel (bon WH/OUT validé) :
      // "picking terminé" confondait "prêt" et "récupéré par le client".
      // `x_pickup_collected` (bouton back-office "Marquer récupérée")
      // distingue maintenant les deux, même schéma que x_delivery_status.
      final collected = order['x_pickup_collected'] == true;
      return (collected ? 'order.prepCompletedPickup' : 'order.prepReadyPickup').tr();
    }
    switch (order['x_delivery_status'] as String?) {
      case 'out_for_delivery':
        return 'order.outForDelivery'.tr();
      case 'delivered':
        return 'order.delivered'.tr();
      default:
        return 'order.prepReadyDelivery'.tr();
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
    default:
      return null;
  }
}
