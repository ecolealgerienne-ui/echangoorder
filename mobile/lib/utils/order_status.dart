import 'package:easy_localization/easy_localization.dart';

/// F08 — libellé du statut de préparation, réutilisé par l'historique
/// (`OrderHistoryScreen`) et le suivi (`OrderTrackingScreen`). `null` si
/// le serveur n'a pas pu résoudre de `stock.picking` pour cette commande
/// (produit non suivi en stock, etc. — voir `order_controller.py.
/// _prep_status`) : les écrans appelants retombent alors sur le libellé
/// générique "Confirmée".
String? prepStatusLabel(Map<String, dynamic> order) {
  final prepStatus = order['prep_status'] as String?;
  final isPickup = order['x_reception_mode'] == 'pickup';
  switch (prepStatus) {
    case 'pending':
      return 'order.prepPending'.tr();
    case 'ready':
      return (isPickup ? 'order.prepReadyPickup' : 'order.prepReadyDelivery').tr();
    case 'completed':
      return (isPickup ? 'order.prepCompletedPickup' : 'order.prepCompletedDelivery').tr();
    default:
      return null;
  }
}
