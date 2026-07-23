import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../navigation/cart_sheet.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import 'pressable_scale.dart';

/// Barre flottante persistante (direction Casbah, décision produit du
/// 2026-07-20 — voir `docs/design_direction.md` § Phase D) : remplace
/// l'onglet Panier de la barre de navigation. `bottomNavigationBar` de
/// `MainTabScaffold` (la barre de navigation à onglets elle-même a été
/// retirée le 2026-07-21, voir ce fichier) — visible sur les 2 onglets
/// restants tant que le panier n'est pas vide, masquée sinon plutôt que
/// d'afficher une barre "0 article, 0 DA" sans utilité.
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    // `hasActiveCart` (pas `itemCount` seul) — bug signalé par l'utilisateur
    // (2026-07-23) : une commande déjà confirmée (`state != 'draft'`) reste
    // "le panier courant" côté serveur (modifiable pré-prise en charge,
    // voir CLAUDE.md § Statuts de commande) mais ne doit plus jamais être
    // présentée comme panier actif ici, même si elle a des lignes.
    if (!cart.hasActiveCart) return const SizedBox.shrink();

    final tokens = AppColorTokens.of(context);
    // `IntrinsicHeight` (bug trouvé par l'utilisateur, 2026-07-21) : tant
    // que `CartBar` était le 1er enfant d'un `Column(mainAxisSize: min)`
    // passé à `Scaffold.bottomNavigationBar` (avec la `NavigationBar` en
    // second), le `Column` shrink-wrap imposait une hauteur bornée à
    // l'ensemble. Une fois `CartBar` seul passé directement à
    // `bottomNavigationBar` (barre de navigation retirée), plus rien ne
    // bornait explicitement sa hauteur — `Scaffold` lui donne une
    // contrainte de hauteur non bornée par le haut pour ce slot, que
    // `Container`/`Row` remplissaient alors entièrement (le panier
    // "prenait toute la page" au lieu d'une barre fine). `IntrinsicHeight`
    // force la sous-arborescence à ne prendre que sa hauteur de contenu
    // réelle, quelle que soit la contrainte ambiante.
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: PressableScale(
          child: Material(
            color: tokens.primary,
            borderRadius: BorderRadius.circular(AppLayout.radius),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppLayout.radius),
              onTap: () => showCartSheet(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: AppLayout.minTouchHeight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tokens.surface.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Text('${cart.itemCount}', style: TextStyle(color: tokens.surface, fontSize: 12)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'cart.viewCart'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.surface),
                      ),
                    ),
                    Text(
                      formatPrice(context, cart.amountTotal),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.surface, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.keyboard_arrow_up, color: tokens.surface, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
