import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../utils/order_status.dart';
import '../../widgets/app_button.dart';
import '../../widgets/shimmer_loader.dart';

/// F09 (détail) — données réelles de la commande (`sale.order` + ses
/// lignes). Le suivi temps réel complet (statuts `stock.picking`
/// synchronisés, notifications push — F08/F11) reste hors scope : seul
/// l'état Odoo de base (`state`) est affiché ici, pas d'étapes
/// préparation/livraison détaillées.
class OrderTrackingScreen extends StatefulWidget {
  final String orderRef;

  const OrderTrackingScreen({super.key, required this.orderRef});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<_OrderDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _detailFuture = _fetchDetail();
    });
  }

  Future<_OrderDetail> _fetchDetail() async {
    final api = context.read<OdooApiClient>();
    final detail = await api.getOrderDetail(orderRef: widget.orderRef);
    final order = detail['order'] as Map<String, dynamic>;
    final lines = (detail['lines'] as List).cast<Map<String, dynamic>>();
    return _OrderDetail(order: order, lines: lines);
  }

  Future<void> _confirmCancel(BuildContext context, int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('screens.OrderTracking.title'.tr()),
        content: Text('${'actions.cancelOrder'.tr()} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('order.keepOrder'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('order.confirmCancel'.tr(), style: TextStyle(color: AppColorTokens.of(dialogContext).danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<OdooApiClient>().cancelOrder(orderId: orderId);
      if (!context.mounted) return;
      AppMessenger.showInfo(context, 'order.cancelled');
      _load();
    } on AppError catch (e) {
      if (context.mounted) AppMessenger.showError(context, e, onRetry: () => _confirmCancel(context, orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.OrderTracking.title'.tr())),
      body: SafeArea(
        child: FutureBuilder<_OrderDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _OrderTrackingSkeleton();
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _load);
            }

            final detail = snapshot.data!;
            final order = detail.order;
            final state = order['state'] as String?;
            final receptionMode = order['x_reception_mode'] as String?;
            final creneau = parseOdooDatetime(order['x_creneau'] as String?);
            final modeLabel = receptionMode == 'home_delivery'
                ? 'checkout.deliveryHome'.tr()
                : receptionMode == 'pickup'
                    ? 'checkout.pickupStore'.tr()
                    : null;
            // Timeline visuelle (direction Casbah, phase E) : `null` pour une
            // commande annulée (pas de progression à montrer dans ce cas,
            // juste le badge "Annulée" ci-dessous).
            final timeline = orderTimelineProgress(order);

            // F16 — décision produit 2026-07 (revue suite à un bug signalé :
            // le bouton restait affiché même pour une commande déjà
            // livrée/récupérée). `state == 'sale'` ne suffit plus comme
            // critère depuis la refonte du cycle de vie (F08) : il reste
            // `sale` de la prise en charge jusqu'à la livraison, sans se
            // remettre à jour ensuite. Le vrai critère est `prep_status` —
            // annulable pendant "en attente de prise en charge" (`sent`) et
            // pendant la préparation, y compris "en cours" (`in_progress`,
            // un opérateur a commencé mais peut toujours reposer les
            // articles), bloqué dès que la commande est prête/livrée/
            // récupérée (`completed`). Même logique que `order_controller.
            // py._can_cancel()`, dupliquée ici pour l'affichage — la
            // vérification qui compte reste côté serveur.
            final prepStatus = order['prep_status'] as String?;
            final canCancel = state == 'sent' ||
                (state == 'sale' &&
                    (prepStatus == null || prepStatus == 'pending' || prepStatus == 'in_progress'));

            // `ScreenPlaceholder` construit son propre Scaffold/AppBar (voir
            // widgets/screen_placeholder.dart) — cet écran a déjà le sien
            // au-dessus (pour garder l'AppBar visible pendant le
            // chargement/en cas d'erreur, avant que `order` ne soit connu).
            // L'utiliser ici aussi empilait 2 AppBar "Suivi de commande"
            // l'une sous l'autre (bug signalé par l'utilisateur, capture
            // d'écran) — reproduit ici la même mise en page (padding,
            // espacement) sans le Scaffold/AppBar en double.
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrackingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${'common.reference'.tr()} ${widget.orderRef}'),
                        if (modeLabel != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(modeLabel),
                        ],
                        if (creneau != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '🕐 ${creneau.hour.toString().padLeft(2, '0')}h${creneau.minute.toString().padLeft(2, '0')}',
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text('${'cart.total'.tr()} : ${formatPrice(context, order['amount_total'] as num)}'),
                        const SizedBox(height: AppSpacing.md),
                        if (timeline == null)
                          Text(
                            '❌ ${'order.statusCancelled'.tr()}',
                            style: TextStyle(color: AppColorTokens.of(context).danger),
                          )
                        else
                          _StatusTimeline(progress: timeline),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TrackingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${detail.lines.length} ${'checkout.itemsLabel'.tr()}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (final line in detail.lines)
                          Text('• ${line['name']} x${line['product_uom_qty']}'),
                      ],
                    ),
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'actions.cancelOrder'.tr(),
                      onPressed: () => _confirmCancel(context, order['id'] as int),
                      variant: AppButtonVariant.danger,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderDetail {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> lines;

  const _OrderDetail({required this.order, required this.lines});
}

/// Regroupement en carte (ombre, direction Casbah — voir
/// `docs/design_direction.md`) plutôt que du texte directement sur le fond
/// de l'écran.
class _TrackingCard extends StatelessWidget {
  final Widget child;

  const _TrackingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColorTokens.of(context).surface,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        boxShadow: AppElevation.of(context),
      ),
      child: child,
    );
  }
}

enum _StepState { done, current, upcoming }

/// Timeline verticale du cycle de vie de la commande (F08, direction
/// Casbah phase E) — dot + ligne de connexion + libellé par étape, plutôt
/// qu'un simple libellé de statut isolé.
class _StatusTimeline extends StatelessWidget {
  final OrderTimelineProgress progress;

  const _StatusTimeline({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < progress.steps.length; i++)
          _StatusTimelineRow(
            label: progress.steps[i],
            state: i < progress.currentIndex
                ? _StepState.done
                : i == progress.currentIndex
                    ? _StepState.current
                    : _StepState.upcoming,
            isLast: i == progress.steps.length - 1,
          ),
      ],
    );
  }
}

class _StatusTimelineRow extends StatelessWidget {
  final String label;
  final _StepState state;
  final bool isLast;

  const _StatusTimelineRow({required this.label, required this.state, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColorTokens.of(context);
    final color = state == _StepState.upcoming ? tokens.border : tokens.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _StepState.upcoming ? Colors.transparent : color,
                  border: Border.all(color: color, width: 2),
                ),
                child: state == _StepState.done ? Icon(Icons.check, size: 12, color: tokens.surface) : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: state == _StepState.upcoming ? tokens.textMuted : tokens.text,
                      fontWeight: state == _StepState.current ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette chatoyant pendant le chargement du suivi (direction Casbah,
/// phase E) — remplace le spinner générique.
class _OrderTrackingSkeleton extends StatelessWidget {
  const _OrderTrackingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShimmerBox(width: 160, height: 16),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(width: 120, height: 14),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            ShimmerBox(width: double.infinity, height: 16),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
