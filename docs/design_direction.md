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

- **Affichage (titres, marque)** : cible *Iowan Old Style / Palatino* — serif chaleureuse, esprit enseigne peinte à la main. À intégrer comme asset Flutter (police embarquée, aucune dépendance réseau) plutôt qu'un `google_fonts` chargé à la volée — cohérent avec le principe déjà en place d'éviter les dépendances externes évitables.
- **Arabe (titres)** : cible *El Messiri* — rond, chaleureux, bonne lisibilité écran, pairing naturel avec la serif ci-dessus en registre.
- **Corps de texte (FR + AR)** : police système par défaut de Flutter (Roboto/San Francisco selon plateforme) — la personnalité typographique reste réservée aux titres, pas au texte courant, pour ne pas complexifier le rendu RTL sur les écrans denses (checkout, profil).

### Langage de formes

- Coins de carte/en-tête légèrement arrondis, angle supérieur plus prononcé (clin d'œil à l'arc en fer à cheval de l'architecture mauresque) plutôt qu'un rayon uniforme sur les 4 coins — ex. `border-radius: 30px 30px 10px 10px` sur les conteneurs pleine largeur (en-tête, feuille de panier).
- Boutons/badges : formes simples (cercle, rectangle à coins doux) — pas de découpes complexes, contrairement à la piste Zellige archivée ci-dessous.

### Mode sombre

Prévu dès cette passe (pas ajouté après coup) : `ColorScheme.dark` complet dans `buildAppTheme()`, bascule via `ThemeMode.system` par défaut (à confirmer — écran de réglage dédié hors scope sauf demande explicite).

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
| D — Panier/Checkout en bottom sheet | Panier persistant en feuille extensible plutôt que route dédiée | `screens/cart/*`, `navigation/app_router.dart` |
| E — Suivi commande & Historique | Timeline visuelle du statut (F08, déjà 5 étapes en logique — habillage seulement), cartes commande avec ombre | `screens/order/*` |
| F — Passe RTL/dark mode/accessibilité | Vérifier chaque écran modifié en arabe + mode sombre + contraste plein soleil | Tous les écrans touchés |

Méthode : une phase à la fois, commit + push après chacune, validation réelle (`flutter run`) par l'utilisateur avant d'enchaîner — pas de vérification visuelle possible depuis le sandbox Claude Code.
