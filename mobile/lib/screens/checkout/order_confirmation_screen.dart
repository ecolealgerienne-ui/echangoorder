import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/odoo_api_client.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/screen_placeholder.dart';

/// F08 — confirmation affichée juste après `CheckoutSummaryScreen` (données
/// réelles renvoyées par `/echango/checkout/confirm`, transmises via
/// `extra`). Le suivi détaillé (statuts synchronisés, notifications push)
/// reste hors de cette passe — voir `order_tracking_screen.dart`.
class OrderConfirmationScreen extends StatefulWidget {
  final String orderRef;
  final double? amountTotal;
  final String? receptionMode;
  final String? slotStart;

  const OrderConfirmationScreen({
    super.key,
    required this.orderRef,
    this.amountTotal,
    this.receptionMode,
    this.slotStart,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    // specs F14 : permission notifications demandée après la première
    // commande confirmée (pas au lancement de l'app).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestNotificationPermission(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = parseOdooDatetime(widget.slotStart);
    final modeLabel = widget.receptionMode == 'home_delivery'
        ? 'checkout.deliveryHome'.tr()
        : widget.receptionMode == 'pickup'
            ? 'checkout.pickupStore'.tr()
            : null;

    return PopScope(
      canPop: false,
      child: ScreenPlaceholder(
        screenKey: 'OrderConfirmation',
        showAppBar: false,
        actions: [
          PlaceholderAction(
            label: () => 'actions.trackOrder'.tr(),
            // Navigation inter-onglets (Panier -> Profil), simple avec go_router :
            // pas besoin de passer par le navigator parent comme en React Native.
            onPressed: () => context.go('/profile/orders/${widget.orderRef}'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${'common.reference'.tr()} ${widget.orderRef}'),
            if (modeLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(modeLabel),
            ],
            if (slot != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('🕐 ${slot.hour.toString().padLeft(2, '0')}h${slot.minute.toString().padLeft(2, '0')}'),
            ],
            if (widget.amountTotal != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('${'checkout.paymentOnDelivery'.tr()} : ${formatPrice(context, widget.amountTotal!)}'),
            ],
          ],
        ),
      ),
    );
  }
}
