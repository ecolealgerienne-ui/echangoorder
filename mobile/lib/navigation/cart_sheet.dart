import 'package:flutter/material.dart';
import '../screens/cart/cart_screen.dart';
import 'sheet_page.dart';

/// Panier flottant persistant (direction Casbah, décision produit du
/// 2026-07-20 — voir `docs/design_direction.md` § Phase D) : le panier
/// n'est plus un onglet de la barre de navigation, il s'ouvre en feuille
/// par-dessus l'écran courant (Accueil ou Profil), déclenché par
/// `widgets/cart_bar.dart`. Réutilise [CartScreen] tel quel (déjà testé en
/// réel) — son propre `Scaffold`/`AppBar` s'affiche normalement à
/// l'intérieur de la feuille, `Navigator.canPop` étant vrai ici (la feuille
/// est elle-même une route), un bouton retour y apparaît automatiquement en
/// plus du geste de balayage vers le bas standard des feuilles modales.
Future<void> showCartSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: SheetShell(child: const CartScreen()),
    ),
  );
}
