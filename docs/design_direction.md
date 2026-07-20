# Direction visuelle — Echango Order

**Décision produit (2026-07-20)** : direction **Casbah** retenue. Ce document fixe les tokens (couleurs, typographie, langage de formes) qui serviront de base à la mise à jour du thème Flutter (`mobile/lib/theme/app_theme.dart`), et archive les deux autres pistes proposées pour référence future.

## Contexte

Constat de départ (audit du thème existant, `app_theme.dart`) : un seul accent vert (`#1F8A55`) sur fond blanc, cartes produit plates sans profondeur, icônes Material génériques, aucun mode sombre. Fonctionnellement complet (18 fonctionnalités branchées sur Odoo) mais visuellement générique — proche de ce que proposent par défaut la plupart des apps de livraison régionales (Yassir, Glovo, Talabat, Jumia Food).

Plutôt que de choisir un accent au hasard, trois directions ont été proposées, chacune ancrée dans un référent maghrébin réel (un lieu, un moment, un motif) plutôt qu'un moodboard générique. Les trois évitent délibérément les clichés visuels génériques (cartes à bordure arrondie uniforme, accent unique sur fond crème + police serif, icônes Material par défaut).

## Direction retenue : Casbah

**Référence** : Alger la Blanche — murs chaulés, portes et volets bleus des ruelles de la Casbah, toits de tuile en accent rare.

**Pourquoi celle-ci** : le meilleur rapport impact/risque pour une petite équipe qui doit encore livrer F11/F12 après le déploiement VPS — elle règle les deux problèmes concrets (accent unique trop clinique, cartes plates) sans renier le vert déjà présent dans toute l'app (conservé comme nuance secondaire, pas jetée) ni exiger de formes complexes (`ClipPath`) à valider écran par écran en Flutter/RTL.

### Palette

| Rôle | Clair | Sombre |
|---|---|---|
| Fond (`background`) | `#F1F3F2` (chaux, cool cast) | `#0E1A20` |
| Surface (cartes) | `#FFFFFF` | `#16262D` |
| Encre (texte) | `#16232B` | `#EDF3F2` |
| Texte atténué | `#5C6B70` | à dériver (encre à ~65% d'opacité) |
| **Primaire (CTA, portes bleues)** | `#1C5271` | `#5B9DBF` |
| **Secondaire (vert hérité, succès/confirmé)** | `#1F8A55` | à dériver (même logique que l'actuel) |
| Accent rare (tuile, promo uniquement) | `#B5622E` | à dériver, usage inchangé (badges promo seulement) |
| Bordure/hairline | `#DDE3E0` | à dériver |

Le vert actuel (`AppColors.primary` dans `app_theme.dart`) devient `AppColors.secondary` — réservé aux états de succès/confirmation (déjà son usage implicite dans les badges "✅" de l'historique de commandes) plutôt qu'à tous les boutons d'action.

### Typographie

- **Affichage (titres, marque)** : cible *Lora* (licence OFL, Google Fonts) — serif chaleureuse, même esprit "enseigne peinte à la main" que la référence initiale *Iowan Old Style/Palatino* évoquée lors de la présentation des 3 pistes, mais celle-ci est une police système propriétaire Apple/Linotype **non redistribuable** comme asset Flutter (pas de licence d'intégration) — corrigé ici pour une famille réellement embarquable.
- **Arabe (titres)** : cible *El Messiri* (licence OFL, Google Fonts) — rond, chaleureux, bonne lisibilité écran, pairing naturel avec *Lora* en registre.
- **Corps de texte (FR + AR)** : police système par défaut de Flutter (Roboto/San Francisco selon plateforme) — la personnalité typographique reste réservée aux titres, pas au texte courant, pour ne pas complexifier le rendu RTL sur les écrans denses (checkout, profil).

#### Étape locale requise (ce sandbox n'a pas accès réseau)

`app_theme.dart` référence déjà deux familles sur les styles de titre (`titleLarge`/`titleMedium`) : `'CasbahDisplay'` (latin, `fontFamily`) avec `'CasbahDisplayArabic'` en repli (`fontFamilyFallback`) — Flutter ne fusionne pas deux polices de scripts différents sous un seul nom de famille (contrairement à plusieurs graisses d'une même police), d'où deux familles déclarées séparément et reliées par le mécanisme de repli. Tant qu'elles ne sont pas déclarées dans `pubspec.yaml`, Flutter retombe silencieusement sur la police système par défaut (aucun risque de casse). Pour les activer :

1. Télécharger les fichiers statiques (`.ttf`) de [Lora](https://fonts.google.com/specimen/Lora) (poids SemiBold/Bold) et de [El Messiri](https://fonts.google.com/specimen/El+Messiri) (poids SemiBold/Bold) depuis Google Fonts.
2. Les placer dans `mobile/assets/fonts/` (nouveau dossier à créer).
3. Ajouter dans `mobile/pubspec.yaml`, sous `flutter:` :
   ```yaml
   fonts:
     - family: CasbahDisplay
       fonts:
         - asset: assets/fonts/Lora-SemiBold.ttf
           weight: 600
     - family: CasbahDisplayArabic
       fonts:
         - asset: assets/fonts/ElMessiri-SemiBold.ttf
           weight: 600
   ```
4. `flutter pub get` puis relancer l'app (pas juste hot reload — un changement de `pubspec.yaml` nécessite un restart complet).

### Langage de formes

- Coins de carte/en-tête légèrement arrondis, angle supérieur plus prononcé (clin d'œil à l'arc en fer à cheval de l'architecture mauresque) plutôt qu'un rayon uniforme sur les 4 coins — ex. `border-radius: 30px 30px 10px 10px` sur les conteneurs pleine largeur (en-tête, feuille de panier).
- Boutons/badges : formes simples (cercle, rectangle à coins doux) — pas de découpes complexes, contrairement à la piste Zellige archivée ci-dessous.

### Mode sombre

**Fait (Phase A, 2026-07-20)** : `AppColorsDark` (tons sombres pour chaque rôle) + `buildAppDarkTheme()` dans `app_theme.dart`, branché dans `main.dart` via `darkTheme:`/`themeMode: ThemeMode.system` (suit le réglage système, pas d'écran de préférence dédié — hors scope sauf demande explicite). Couverture actuelle : le chrome Material standard (AppBar, boutons, `Scaffold`, texte via `TextTheme`) bascule déjà correctement. Les widgets qui référencent `AppColors.*` directement (`ProductGridTile`, écrans panier/checkout/profil...) ne suivent pas encore le mode sombre — bascule progressive prévue phase par phase (B-E) à mesure que chaque composant/écran est retouché.

## Pistes archivées (non retenues pour l'identité permanente)

### Souk

Référence : étals du souk à la tombée du jour — indigo (`#1B1B33`), safran (`#E0932A`), menthe (`#4E9C82`), harissa (`#C6432A`) en alerte/promo. Direction la plus énergique et la plus démarquée de la concurrence régionale, mais rupture complète avec l'identité actuelle et charge d'implémentation plus lourde (motif dentelé en `ClipPath` sur en-têtes/badges). **Piste à garder en réserve** pour un habillage saisonnier (Ramadan, campagne promo) plutôt que l'identité permanente.

### Zellige

Référence : le motif géométrique du carreau maghrébin — émeraude (`#0E6E5C`), filet doré (`#B8912F`), découpes octogonales sur les cartes plutôt que des coins arrondis. Direction la plus premium et la plus "propriétaire" à long terme, mais la plus exigeante à exécuter proprement (découpes `ClipPath` à soigner sur tous les formats d'écran) et sans continuité avec le vert actuel. **Évolution naturelle envisageable une fois Casbah stabilisé**, si l'équipe a le temps de soigner l'exécution.

## Plan de mise à jour (phases)

| Phase | Contenu | Fichiers principaux |
|---|---|---|
| A — Fondations | Palette Casbah (2 accents + secondaire hérité) + mode sombre dans `ColorScheme`, police display FR/AR (asset embarqué), ombres/élévation, courbes d'animation standard | `theme/app_theme.dart` |
| B — Composants partagés | `AppButton`, `ProductGridTile` (ombre + micro-interaction ajout panier), nouveau `ShimmerLoader`, set d'illustrations pour `ErrorStateView` | `widgets/app_button.dart`, `widgets/product_grid_tile.dart`, nouveau `widgets/shimmer_loader.dart`, `errors/error_state_view.dart` |
| C — Accueil & Catalogue | Bandeau catégories + recherche visible dès l'Accueil, remplacement spinners → shimmer | `screens/home/home_screen.dart`, `screens/catalog/catalog_screen.dart` |
| D — Panier/Checkout en bottom sheet | Tunnel checkout présenté en feuille (glisse depuis le bas, coins arrondis, fond assombri) ; cartes lignes de panier avec ombre | `navigation/sheet_page.dart` (nouveau), `navigation/app_router.dart`, `screens/cart/cart_screen.dart` |
| E — Suivi commande & Historique | Timeline visuelle du statut (F08, déjà 5 étapes en logique — habillage seulement), cartes commande avec ombre | `screens/order/*` |
| F — Passe RTL/dark mode/accessibilité | Vérifier chaque écran modifié en arabe + mode sombre + contraste plein soleil | Tous les écrans touchés |

Méthode : une phase à la fois, commit + push après chacune, validation réelle (`flutter run`) par l'utilisateur avant d'enchaîner — pas de vérification visuelle possible depuis le sandbox Claude Code.

### Phase D — décision de périmètre (2026-07-20)

L'idée initiale ("panier persistant en feuille extensible plutôt que route dédiée") impliquait de retirer le Panier de la barre d'onglets (`StatefulShellRoute.indexedStack`, `MainTabScaffold`) pour le remplacer par une barre flottante persistante ouvrant une feuille par-dessus les autres onglets. **Périmètre réduit en cours de route** : cette restructuration touche l'architecture de navigation principale — déjà testée en réel par l'utilisateur (4 onglets, "j'ai fait tous les tests, c'est ok") — sans qu'aucune vérification visuelle ne soit possible dans ce sandbox avant de la pousser. Risque jugé disproportionné par rapport au gain esthétique.

**Ce qui a été fait à la place** : le panier reste un onglet classique (aucun changement à `MainTabScaffold`/`StatefulShellRoute`) ; c'est le **tunnel checkout** (`/cart/checkout/*`, déjà des routes poussées par-dessus l'onglet, pas des onglets eux-mêmes) qui adopte la présentation "feuille" — glisse depuis le bas, coins supérieurs arrondis (`AppShape.archTop`), fond assombri derrière (`navigation/sheet_page.dart`, `sheetPage()`). Changement purement présentationnel (transition + habillage), aucune topologie de route modifiée. Les lignes du panier gagnent aussi une carte avec ombre (cohérence visuelle avec `ProductGridTile`, phase B) et la barre de résumé en bas devient "ancrée" (ombre portée vers le haut plutôt qu'un simple filet).

Si le panier flottant persistant reste souhaité, ce serait une décision produit à part entière (retrait d'un onglet testé) à valider explicitement plutôt qu'un simple ajustement visuel — non fait ici.
