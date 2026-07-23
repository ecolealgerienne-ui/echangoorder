import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Présentation "feuille" (direction Casbah, phase D — voir
/// `docs/design_direction.md`) pour le tunnel checkout : glisse depuis le
/// bas, coins supérieurs arrondis ([AppShape.archTop]), fond assombri
/// derrière plutôt qu'un simple push plein écran.
CustomTransitionPage<void> sheetPage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    barrierColor: Colors.black54,
    // Pas de fermeture au tap sur le fond assombri : le tunnel checkout
    // porte des saisies (adresse, créneau...) qu'une fermeture accidentelle
    // rendrait frustrante — la fermeture reste au bouton retour/croix de
    // chaque écran, comme un push classique.
    barrierDismissible: false,
    transitionDuration: AppMotion.standard,
    reverseTransitionDuration: AppMotion.standard,
    child: SheetShell(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .chain(CurveTween(curve: AppMotion.curve))
          .animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

/// Habillage visuel partagé des feuilles (checkout via [sheetPage], panier
/// via `navigation/cart_sheet.dart`) : poignée de glissement + coins
/// supérieurs arrondis sur fond du thème courant.
class SheetShell extends StatelessWidget {
  final Widget child;

  const SheetShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: ClipRRect(
          borderRadius: AppShape.archTop,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColorTokens.of(context).border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
