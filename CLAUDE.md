# CLAUDE.md

## ⚠️ Règle impérative — synchronisation avant toute nouvelle branche

**Avant de créer une nouvelle branche, il faut impérativement synchroniser avec toutes les branches distantes** (`git fetch --all`) afin de ne rien perdre et de récupérer tous les commits existants dans la nouvelle branche (partir de l'état le plus à jour, typiquement `origin/main`, plutôt que d'un historique local potentiellement obsolète). Ne jamais créer une branche à partir d'un état local non synchronisé.

Ce fichier guide Claude Code (et tout contributeur) sur le contexte, les conventions et les décisions du projet **Echango Order**. Pour l'avancement fonctionnel détaillé, voir `status-V1.md`.

## Contexte projet

Echango Order est une app mobile de commande alimentaire (livraison à domicile ou retrait en magasin), premier client "dogfooding" de la plateforme B2B **Echango Delivery** (Fleetbase). Les deux produits sont décrits dans `docs/specs_macro_drive_transport.md`.

La **Phase 1 (MVP)** ne concerne que l'app mobile client, spécifiée dans `docs/specs_phase1_echango_order.md` (v1.5 — 18 fonctionnalités F00 à F17). **Toujours consulter ces deux documents avant de développer une fonctionnalité** : wireframes, endpoints Odoo attendus, champs custom, critères d'acceptation QA.

## Stack technique (Phase 1)

- **Frontend mobile** : Flutter (iOS & Android), bilingue FR/AR avec support RTL natif
- **Backend** : Odoo 19, API JSON-RPC (`/web/dataset/call_kw`)
- **Notifications** : Firebase Cloud Messaging
- **Paiement** : cash uniquement — aucune intégration paiement en ligne en Phase 1
- **Auth** : téléphone + PIN **6 à 12 chiffres** (`kPinMinLength`/`kPinMaxLength` dans `mobile/lib/validation/validators.dart`), endpoint custom Odoo, PIN hashé, stockage session via Keychain/Keystore

> Écarts assumés vs les specs (qui restent la référence fonctionnelle par ailleurs) : stack basculée de React Native vers **Flutter** en cours de projet (historique dans le log git) ; PIN étendu à **6-12 chiffres** au lieu de 4 fixes (plus d'entropie) — impacte tout écran de saisie/confirmation PIN et `x_pin` côté Odoo.

## Périmètre Phase 1

| # | Fonctionnalité |
|---|---|
| F00 | Vitrine publique (sans compte) |
| F01 | Onboarding |
| F02 | Authentification (inscription téléphone/PIN, connexion, invité) |
| F03 | Accueil |
| F04 | Catalogue & Recherche (fusionné dans F03, voir ci-dessous) |
| F05 | Fiche Produit |
| F06 | Panier |
| F07 | Checkout & Mode de Réception (livraison / retrait, créneau, zone de livraison) |
| F08 | Confirmation & Suivi Commande |
| F09 | Historique Commandes & Reorder (1 tap) |
| F10 | Profil Utilisateur |
| F11 | Notifications Push (Phase 1.5) |
| F12 | Partage Produit / Deep Link (partage en Phase 1, réception en Phase 1.5) |
| F13 | Pages Légales |
| F14 | Permissions & États Système |
| F15 | Code Promo |
| F16 | Annulation Commande |
| F17 | Gestion Substitution Produit |

**Hors périmètre Phase 1** (specs §5) : paiement en ligne, programme fidélité, GPS temps réel, app Préparateurs, app Transporteur, intégration Fleetbase active, filtres avancés catalogue, avis produits.

**Navigation actuelle** (décision produit, 2026-07-20/21, remplace le wireframe d'origine) : 2 onglets seulement (Accueil/Profil), `AppBar` commune (`common.appName`, bouton icône unique pour basculer d'onglet), panier en feuille flottante (`CartBar`, plus un onglet dédié). F04 fusionné dans l'Accueil — le bandeau catégories filtre directement la grille (`categ_id` sur le `search_read`) au lieu de naviguer vers un écran dédié ; recherche texte supprimée (catalogue plafonné à ~300 produits, le filtre catégories suffit).

### Phase 1.5

**F11 (Notifications Push) et F12 (réception du deep link) reportées** — code-complètes, bloquées par un déploiement réel non encore fait :
- F11 nécessite un projet FCM en production + un webhook Odoo joignable depuis l'extérieur (VPS requis, pas testable en Docker/WSL local).
- F12 : le bouton de partage fonctionne déjà ; seule la **réception** (Universal/App Links) est reportée — nécessite un domaine réel + publication effective sur les stores.

### Images produit — S3 au déploiement VPS

Actuellement en base64 dans le JSON (`Image.memory(base64Decode(...))`) — point de performance connu. **Au déploiement VPS, migrer directement vers une URL S3** (champ URL côté Odoo ou module de stockage S3) + un vrai widget d'image réseau avec cache disque côté Flutter — pas d'étape intermédiaire par `/web/image/<model>/<id>/<field>` qu'il faudrait ensuite re-migrer.

## Exigences transversales (non négociables)

- **Sécurité** : HTTPS/TLS 1.3 partout, PIN jamais stocké en clair, session expirée après 24h d'inactivité, délai progressif anti brute-force sur le PIN (1s/2s/4s/8s puis blocage après 5 échecs), endpoints publics filtrés + rate limités.
- **i18n** : toutes les chaînes externalisées, RTL complet en arabe testé sur chaque écran, formats date/heure localisés.
- **Performance** : accueil < 2s, API < 1s, app < 50 Mo.
- **Accessibilité** : police min 14px, boutons min 44px de hauteur, contraste lisible en plein soleil.
- **Gestion d'erreurs** : message clair hors-ligne, retry automatique sur échec API, aucune erreur silencieuse.

## Structure du repo

- `docs/` — specs macro, Phase 1, direction visuelle, préparation groupée (voir § Documentation).
- `mobile/` — app Flutter. `lib/` : `navigation/` (`app_router.dart` + go_router, `main_tab_scaffold.dart`), `screens/` (un dossier par domaine F00-F17), `state/` (`auth_state.dart`, `cart_state.dart`, `locale_state.dart` — `ChangeNotifier` + `provider`), `services/` (`permission_service.dart`), `errors/` (voir § Gestion des erreurs), `validation/`, `theme/`, `widgets/` (composants partagés), `utils/`. Traductions dans `assets/translations/` (`fr.json`/`ar.json`, `easy_localization`).
- `mobile/android/` et `mobile/ios/` : **pas générés par Claude Code** (voir § Environnement de dev — app mobile).
- `backend/` — Odoo 19 + Postgres via Docker (WSL côté utilisateur). `addons/echango_order/` (module custom).

## Environnement de dev — app mobile

Développement côté utilisateur sous **Windows / PowerShell**, avec Android Studio. Toute commande shell suggérée doit être en syntaxe PowerShell (`Remove-Item -Recurse -Force` au lieu de `rm -rf`, `Get-Content` au lieu de `cat`, etc.) — en cas de doute, préférer une commande `flutter`/`dart` multiplateforme.

Commandes courantes (depuis `mobile/`) : `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`, `flutter doctor`.

**Permissions natives (`permission_handler`, F14)** : déclarations natives à ajouter après `flutter create .` en local —
- Android (`android/app/src/main/AndroidManifest.xml`, avant `<application>`) : `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`.
- iOS (`ios/Runner/Info.plist`) : `NSLocationWhenInUseUsageDescription`. Activer aussi les macros `PERMISSION_LOCATION`/`PERMISSION_NOTIFICATIONS` dans `ios/Podfile` (voir README `permission_handler` sur pub.dev).

Sans ces déclarations, `flutter run` compile mais la demande de permission plante ou est refusée silencieusement au runtime.

**Limite d'environnement (sandbox Claude Code)** : pas d'accès au SDK Flutter/Dart (réseau bloque `storage.googleapis.com`) — ni `flutter create`, ni `analyze`/`run`/`test` possibles ici. `mobile/android/`/`mobile/ios/` n'existent donc pas dans le repo : après avoir récupéré du code Flutter écrit par Claude Code, lancer une fois en local :
```powershell
flutter create --org com.echangoorder .
flutter pub get
flutter analyze
```
(`flutter create .` sur un dossier avec `pubspec.yaml` existant n'ajoute que les dossiers de plateforme manquants, ne touche ni `lib/` ni `pubspec.yaml`.) Toute vérification réelle se fait côté utilisateur, qui colle les erreurs dans la conversation.

## Environnement de dev — backend Odoo

Odoo 19 tourne via **Docker** dans **WSL** côté utilisateur (pas dans ce sandbox). Tout se passe dans `backend/`.

```bash
cd backend
cp .env.example .env
docker compose up -d
```
Puis `http://localhost:8069` — créer la base, installer le module `echango_order` (Apps, retirer le filtre par défaut). `-u echango_order` en ligne de commande fonctionne aussi.

Commandes utiles : `docker compose logs -f odoo` (déboguer un module qui ne charge pas), `docker compose down` / `down -v` (repart de zéro), `docker compose restart odoo` (recharge le code Python après une modif — pas de hot-reload côté Odoo).

**WSL** : cloner dans le filesystem WSL (pas `/mnt/c/...`, perf Docker dégradée). Docker Desktop + intégration WSL2, ou Docker Engine natif dans la distro. Port 8069 déjà pris → changer le port publié dans `docker-compose.yml`.

**Limite d'environnement** : pas d'accès à Docker Hub dans ce sandbox — ni pull des images, ni conteneur pour vérifier le travail. `docker-compose.yml` validé avec `docker compose config` uniquement (parsing, sans daemon) — jamais réellement exécuté ici. Toute vérification réelle (`docker compose up`, installation du module, logs d'erreur) se fait côté utilisateur.

## Stratégie d'implémentation

Deux temps : (1) écrans + navigation d'abord en placeholders, intégralement navigables via `go_router`, sans backend ni couche de mock — pour valider le parcours avant toute donnée réelle ; (2) branchement direct sur Odoo ensuite, écran par écran, sans étape intermédiaire de mock.

L'état de session (`state/auth_state.dart`) est un état **client local** durable (pas une simulation de backend) : pilote la navigation dès maintenant (`redirect` de go_router) et reste après le branchement Odoo — seul le contenu du login change.

## Gestion des erreurs (convention — obligatoire pour tout nouveau code)

Toute erreur ou message affiché passe par le système centralisé `mobile/lib/errors/`, jamais par un `ScaffoldMessenger`/`showDialog` direct dans un écran.

- **`app_error.dart`** — `AppError` : une erreur = un **code** (dot-path, ex. `network.offline`) mappé 1:1 sur `errors.*` dans les traductions, jamais un message en dur. Constantes statiques classées par domaine (network, server, auth, validation, checkout, promo, order, permissions).
- **`app_messenger.dart`** — seul point d'affichage : `showError`/`showInfo`/`showErrorDialog`.
- **`error_state_view.dart`** — état plein écran réutilisable (vides, erreurs bloquantes). `ErrorStateView.forError(error, {onRetry})`.

**Pourquoi des codes** : un·e traducteur·rice ne touche que les JSON, jamais le code Dart ; et les erreurs JSON-RPC d'Odoo se mappent vers ces mêmes constantes dans la couche d'appel API sans toucher à l'affichage. Nouveau cas d'erreur Odoo sans code `AppError` correspondant → ajouter la constante + les 2 traductions avant de l'utiliser.

## Traductions (i18n)

Toute chaîne passe par `easy_localization` (`'clé'.tr()`), jamais de texte en dur — y compris les préfixes de labels. Exceptions tolérées : libellés techniques de debug, noms de langue dans le sélecteur ("Français"/"العربية").

`mobile/test/translations_completeness_test.dart` (à lancer après tout ajout d'écran/clé) vérifie : parité des clés fr/ar, toute clé statique `.tr()` existe dans les deux fichiers, tout `screenKey` de `ScreenPlaceholder` a un title+subtitle dans les deux langues.

**Pièges déjà rencontrés, à ne pas reproduire** :
- Texte figé en français malgré le test qui passe → probablement un souci de rebuild (JSON embarqués au build, hot reload ne les recharge pas) — redémarrage complet requis, pas forcément une traduction manquante.
- `PlaceholderAction.label` (`widgets/screen_placeholder.dart`) doit être un `String Function()` (`label: () => 'clé'.tr()`), jamais une `String` déjà résolue — sinon la langue se fige au premier `build()` de l'écran appelant.
- Les onglets gardés vivants par `StatefulShellRoute`/`IndexedStack` ne se retraduisent pas seuls après `context.setLocale()` — `state/locale_state.dart` (`LocaleState`) force le rebuild : appeler `notifyLocaleChanged()` juste après `setLocale()`, et `context.watch<LocaleState>()` en tête du `build()` de tout écran gardé vivant dans la navigation qui affiche du texte statique.

## Principe architecture Odoo — standard avant custom

**Règle non négociable : s'appuyer au maximum sur les modèles/champs/mécanismes standards d'Odoo.** Un ajout custom (modèle, champ `x_*`, contrôleur HTTP) n'est justifié que si Odoo standard **n'a aucun équivalent** — à vérifier explicitement avant toute création, et à documenter ici.

**Champs standards réutilisés** (pas de doublon `x_*`) : langue → `res.partner.lang` ; téléphone → `res.partner.phone` (**`mobile` supprimé en Odoo 19**, fusionné dans `phone`) ; adresses → adresses enfants `res.partner` (`type='delivery'`) ; commandes → `sale.order` standard ; GPS → `res.partner.partner_latitude`/`partner_longitude` (champs du module `base` lui-même, pas besoin de `base_geolocalize`). Identité client = utilisateur portail Odoo (`res.users` + `base.group_portal` + `res.partner`), pas de modèle custom séparé.

**Modèles/champs custom justifiés** (aucun équivalent standard trouvé) :
- `x_pin` (hashé, `res.users`) + délai anti brute-force — Odoo n'a pas de notion de PIN.
- `x_reception_mode`, `x_creneau`, `x_firebase_token`, `x_vitrine_publique` (`sale.order`/`res.partner`).
- `x_verification_state` (Selection, `res.partner`) — validation manuelle de compte, voir § Qualité clients.
- `x_last_activity` (Datetime, `res.users`) — `login_date` standard n'est mis à jour qu'à la connexion, pas à chaque appel ; nécessaire à la politique 24h d'inactivité.
- `x_delivery_status`/`x_pickup_collected` (`sale.order`) — voir § Statuts de commande.
- Modèle `x_delivery_zone` — pas de notion de zone de livraison simple en Odoo 19 CE.
- Modèle `x_rate_limit` — pas de rate limiting HTTP intégré pour des contrôleurs custom ; purgé par un `ir.cron` standard.
- Modèle `x_timeslot_capacity` — pas de notion de créneau/capacité nativement.
- Modèle `x_pin_reset_wizard` (`TransientModel`) — assistant de réinitialisation PIN par un modérateur.
- Modèle `x_product_favorite` — pas d'équivalent sans `website_sale` (qui a `product.wishlist` mais nécessite toute l'app eCommerce).
- Modèle `x_substitute_product_ids` (M2M self sur `product.template`) — module OCA `stock_picking_product_interchangeable` vérifié et écarté (relation symétrique/automatique, besoin ici asymétrique/choisi par le client).
- Modèles `x_batch_picking_wizard`/`x_batch_picking_wizard_line` — voir § Préparation groupée.

**Notes Odoo 19 (écarts vs versions antérieures, déjà vérifiés — évite de re-déboguer)** :
- `res.partner.mobile` supprimé, fusionné dans `phone`.
- `res.users.groups_id` renommé `group_ids`.
- `ir.cron.numbercall` supprimé (crons récurrents n'ont plus de compteur d'occurrences).
- `read_group` déprécié → `formatted_read_group` (clé de résultat `__count`, agrégats explicites).
- `product.template.description` est un champ **Html**, pas Text/Char.
- `stock.picking.batch_id` n'existe **pas** dans le module `stock` de base — module séparé `stock_picking_batch` (Community, LGPL-3), à déclarer explicitement en dépendance.
- `stock.picking.sale_id` (résolu depuis `sale_stock`, déjà une dépendance implicite) donne la commande d'origine d'un picking sans nouveau champ de liaison.
- Champs `readonly="1"` peuplés uniquement par défaut/onchange (pas un vrai `compute`) dans un tableau One2many éditable ne sont pas toujours renvoyés au serveur à la sauvegarde — `force_save="1"` est censé résoudre ça mais s'est avéré insuffisant dans ce module (`x_batch_picking_wizard_line`) : seul un vrai champ `compute(store=True)` dépendant d'un champ non-readonly (ex. `order_id` recalculé depuis `picking_id`, lui-même toujours transmis) a réglé le problème durablement.
- `res.config.settings` est réservé par défaut au groupe Réglages (`base.group_system`).

## Favoris (hors périmètre specs initiales, demandé explicitement)

Liste de favoris par client, initialisée automatiquement depuis l'historique de commandes (dédupliqué), modifiable manuellement.

- Modèle `x_product_favorite` (`partner_id`, `product_tmpl_id`, contrainte unique).
- Initialisation dans `models/sale_order.py` (`action_confirm()`/`_seed_favorites()`, lignes de récompense exclues).
- Gestion manuelle via `controllers/favorites_controller.py` (`FavoritesScreen`, Profil).

## Qualité clients — vérification manuelle des nouveaux comptes

Plutôt qu'un service de géocodage externe, un modérateur valide **manuellement** chaque nouveau compte client en back-office avant qu'il puisse commander.

- `res.partner.x_verification_state` (`pending`/`verified`/`rejected`) — défaut `verified` (n'affecte pas les partenaires déjà en base), mis à `pending` uniquement par `/echango/auth/register`.
- Statusbar + boutons "Valider"/"Rejeter" sur la fiche contact (`views/res_partner_views.xml`) + menu "Clients à valider".
- Vérifié à `/echango/checkout/confirm` (seule action qui compte) ; l'app avertit dès le Panier pour éviter de remplir tout le tunnel pour rien.

## Statuts de commande (F08)

Cycle de vie côté client en 5-7 étapes, porté par des mécanismes Odoo standards :

1. **Panier** — `sale.order.state == 'draft'`.
2. **En attente de prise en charge** — le client confirme dans l'app ; commande **reste modifiable**. Réutilise `state == 'sent'` (valeur standard, relabellée `selection_add`) — `checkout_controller.py.confirm()` écrit `state='sent'` directement (pas `action_quotation_sent()`, pensé pour l'email manuel).
3. **En préparation** — l'opérateur clique le bouton **"Confirmer" standard** du devis (`sent`→`sale`, `action_confirm()`) : génère le `stock.picking`, réservation de stock **immédiate** (décision assumée : évite que deux clients confirment sur le même stock avant blocage réel ; pas de bouton "vérifier la disponibilité").
4. **En cours** — `stock.picking.user_id` (champ standard, jamais auto-rempli) assigné par un opérateur → `order_controller.py._prep_status()` renvoie `in_progress`.
5. **Prête** — picking `done` → `completed`. Ne veut **pas** dire "remise au client" (voir 6/7).
6. **Livraison seule : en cours → livrée** — `x_delivery_status` (Selection custom, aucun tracking réel sans intégration transport), 2 boutons back-office (`action_mark_out_for_delivery`/`action_mark_delivered`).
7. **Retrait seul : prête à récupérer → récupérée** — `x_pickup_collected` (Boolean custom), 1 bouton back-office (`action_mark_picked_up`).

`mobile/lib/utils/order_status.dart` (`prepStatusLabel()`) centralise les libellés (historique F09 + suivi F08).

**F16 (annulation)** — `order_controller.py._can_cancel()` : annulable pendant `sent`, et pendant `sale` tant que `prep_status` n'est pas `completed` (y compris `in_progress` — un opérateur qui a commencé peut reposer les articles). Bloqué dès "Prête", quelle que soit la suite. Dupliqué côté `order_tracking_screen.dart` pour l'affichage du bouton.

## Produits de substitution (F17)

**C'est toujours le client qui choisit un substitut, jamais le préparateur** — remplace l'implémentation initiale (préparateur post-confirmation, supprimée : `SubstitutionScreen`, endpoints `/echango/order/substitution*` retirés).

Module OCA `stock_picking_product_interchangeable` vérifié et écarté : relation symétrique + substitution automatique côté `stock.picking`, alors qu'ici c'est le client qui choisit et la relation est volontairement asymétrique.

- `x_substitute_product_ids` (M2M self sur `product.template`) — curé manuellement par l'admin, jamais généré automatiquement.
- Fiche produit (F05) : section "Produits de substitution" si le produit en a (`/echango/catalog/substitutes`).
- Checkout (F07) : `checkout_controller.py.confirm()` remonte toutes les lignes indisponibles d'un coup (`cart.unavailable_products`) avec leurs substituts pré-définis — `CheckoutResolveUnavailableScreen` (client choisit un substitut ou supprime la ligne), confirmation retentée automatiquement.

## Préparation groupée des commandes (batch picking + zone de tri)

Voir `docs/specs_preparation_groupee.md` pour la conception complète (algorithme détaillé, et la base posée pour la future app préparateur). En attendant l'app préparateur, la préparation se fait entièrement dans l'UI back-office Odoo standard — objectif : réduire les déplacements des préparateurs (collecte groupée de plusieurs commandes) et gérer une vraie zone de tri physique (contrôle qualité + séparation par commande).

- **Route Pick + Pack + Ship** (3 étapes, standard `stock`, Community) : Pick = collecte groupée (`stock.picking.batch`), Pack = zone de tri, Ship = inchangé (`picking_type_id.code == "outgoing"`). Activation = config manuelle back-office (Réglages > Inventaire > Multi-Step Routes), pas de code.
- `order_controller.py._prep_status()` regarde désormais **tous** les pickings actifs de la commande (pas seulement le dernier) — sinon le statut app serait resté bloqué sur "pending" pendant tout le Pick+Pack. Rétrocompatible avec l'entrepôt à 1 étape.
- **Seule partie custom, aucun équivalent standard** : le calcul du regroupement optimal (similarité produits, contraintes de capacité). `x_batch_picking_wizard`/`_line` (action tableau de bord, pas d'`active_id`) + moteur glouton pur Python (`models/batch_picking_engine.py`, testé directement en sandbox) : seuil minimal de similarité, tie-break déterministe (ancienneté puis id), règle fair-play (override SLA dur plutôt qu'un score composite). `action_refresh()` (bouton "Recalculer les suggestions") n'ajoute que les commandes pas encore listées, sans jamais toucher aux lignes déjà présentes — numéros de lot des nouvelles suggestions décalés au-delà du plus grand déjà utilisé pour ne jamais fusionner par coïncidence de numérotation avec un lot déjà ajusté manuellement.
- `stock.package` par commande au poste de tri, lié par **convention de nommage** (`package.name = order.name` — aucun champ standard ne relie les deux).
- Paramètres réglables via `res.config.settings` (menu dédié "Paramètres de préparation groupée", pas le formulaire général de l'app Réglages) — `ir.config_parameter` en dessous.
- Conception passée par 3 revues spécialisées avant codage (logistique, Odoo, algorithmique) — voir `docs/specs_preparation_groupee.md` pour le détail.
- **Hors périmètre v1** : app préparateur mobile, automatisation sans validation humaine, chaîne du froid/frais-surgelé, gestion des ruptures de stock découvertes en cours de tournée sur un lot déjà en cours.

## Documentation

- `docs/specs_macro_drive_transport.md` — vision produit globale, roadmap macro, architecture Odoo ↔ Fleetbase.
- `docs/specs_phase1_echango_order.md` — specs détaillées Phase 1 (wireframes, API, critères QA).
- `docs/design_direction.md` — direction visuelle **Casbah** (palette, typographie, plan par phases).
- `docs/specs_preparation_groupee.md` — préparation groupée des commandes, base pour l'app préparateur.
- `status-V1.md` — suivi de l'avancement, à tenir à jour à chaque étape.

## Conventions de travail

- Développer sur la branche dédiée à la tâche en cours, jamais directement sur `main`.
- Mettre à jour `status-V1.md` à chaque fonctionnalité livrée ou changement d'état significatif.
- Respecter les critères d'acceptation QA de chaque fonctionnalité avant de la considérer terminée.
- Tout nouveau champ custom Odoo doit être documenté et validé contre la liste ci-dessus avant création.
- Tout message d'erreur ou d'information affiché passe par `AppMessenger`/`ErrorStateView` — jamais de `ScaffoldMessenger`/`showDialog` direct, jamais de message en dur non traduit.
