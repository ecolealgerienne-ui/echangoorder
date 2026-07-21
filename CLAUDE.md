# CLAUDE.md

## ⚠️ Règle impérative — synchronisation avant toute nouvelle branche

**Avant de créer une nouvelle branche, il faut impérativement synchroniser avec toutes les branches distantes** (`git fetch --all`) afin de ne rien perdre et de récupérer tous les commits existants dans la nouvelle branche (partir de l'état le plus à jour, typiquement `origin/main`, plutôt que d'un historique local potentiellement obsolète). Ne jamais créer une branche à partir d'un état local non synchronisé.

Ce fichier guide Claude Code (et tout contributeur) sur le contexte, les conventions et l'état du projet **Echango Order**.

## Contexte projet

Echango Order est une app mobile de commande alimentaire (livraison à domicile ou retrait en magasin), premier client "dogfooding" de la plateforme B2B **Echango Delivery** (Fleetbase). Les deux produits sont décrits dans `docs/specs_macro_drive_transport.md`.

La **Phase 1 (MVP)** ne concerne que l'app mobile client. Elle est spécifiée en détail dans `docs/specs_phase1_echango_order.md` (specs v1.5 — 18 fonctionnalités F00 à F17, validées par Product Owner / UX Designer / Expert Odoo / QA Engineer).

**Toujours consulter ces deux documents avant de développer une fonctionnalité.** Ils font foi pour : wireframes, endpoints Odoo attendus, champs custom, et critères d'acceptation QA.

## Stack technique (Phase 1)

- **Frontend mobile** : Flutter (iOS & Android), bilingue FR/AR avec support RTL natif
- **Backend** : Odoo 19, API JSON-RPC (`/web/dataset/call_kw`)
- **Notifications** : Firebase Cloud Messaging
- **Paiement** : cash uniquement (à la réception / au retrait) — aucune intégration paiement en ligne en Phase 1
- **Auth** : téléphone + PIN **6 à 12 chiffres** (endpoint custom Odoo, PIN hashé, stockage device via iOS Keychain / Android Keystore)

> **Note** : les specs (`docs/specs_phase1_echango_order.md`, `docs/specs_macro_drive_transport.md`) mentionnent React Native comme stack d'origine. Décision prise en cours de projet de basculer sur **Flutter** (choix de l'équipe, expérience Flutter préalable). Cette section fait foi pour le choix technique actuel ; les specs restent la référence fonctionnelle (écrans, parcours, API, critères QA), inchangée par ce changement de framework. Un premier projet React Native a existé brièvement dans `mobile/` avant d'être remplacé — historique consultable dans le log git si besoin.

> **Note** : les specs prévoient un PIN à **4 chiffres** partout (wireframes F02/F10, critères QA "PIN de 4 chiffres"). Décision produit de passer à un **PIN de 6 à 12 chiffres** pour plus d'entropie (constantes `kPinMinLength`/`kPinMaxLength` dans `mobile/lib/validation/validators.dart`). Impact : tout écran de saisie/confirmation PIN (inscription, connexion, PIN oublié, modification, suppression de compte) et le futur endpoint Odoo (`x_pin` hashé) doivent respecter cette plage, pas 4 chiffres fixes. Le champ `x_pin` (spec Expert Odoo) reste valide, seule sa longueur de saisie change côté app.

## Périmètre Phase 1

18 fonctionnalités (voir `docs/specs_phase1_echango_order.md` section 3) :

| # | Fonctionnalité |
|---|---|
| F00 | Vitrine publique (sans compte) |
| F01 | Onboarding |
| F02 | Authentification (inscription téléphone/PIN, connexion, invité) |
| F03 | Accueil |
| F04 | Catalogue & Recherche |
| F05 | Fiche Produit |
| F06 | Panier |
| F07 | Checkout & Mode de Réception (livraison / retrait, créneau, zone de livraison) |
| F08 | Confirmation & Suivi Commande |
| F09 | Historique Commandes & Reorder (1 tap) |
| F10 | Profil Utilisateur |
| F11 | Notifications Push |
| F12 | Partage Produit (Deep Link) |
| F13 | Pages Légales (CGU, confidentialité, mentions légales) |
| F14 | Gestion des Permissions & États Système (maintenance, permissions) |
| F15 | Code Promo |
| F16 | Annulation Commande |
| F17 | Gestion Substitution Produit |

**Hors périmètre Phase 1** (voir specs §5) : paiement en ligne, programme fidélité, GPS temps réel, app Préparateurs, app Transporteur, intégration Fleetbase active, filtres avancés catalogue, favoris, chat support, avis produits.

**F04 fusionné dans l'Accueil (décision produit, 2026-07-20)** : plus d'écran/onglet Catalogue séparé — le bandeau catégories de `HomeScreen` (F03) filtre directement sa propre grille de produits (`categ_id` ajouté au domaine `search_read`) au lieu de naviguer vers un écran dédié. `CatalogScreen` (liste des catégories) et `CategoryProductsScreen` (grille par catégorie) supprimés, barre de navigation passée de 4 à 3 onglets (Accueil/Panier/Profil). La recherche texte (`SearchScreen`) reste un écran à part entière — déplacée sous l'onglet Accueil (`/home/search`, dossier `screens/search/`) plutôt que `screens/catalog/` (dossier supprimé, ne contenait plus qu'elle).

### Phase 1.5 (décision produit, 2026-07-20)

**F11 (Notifications Push) et F12 (Partage Produit — réception du deep link uniquement) sont reportées en Phase 1.5**, retirées du périmètre de clôture de la Phase 1 — toutes deux sont code-complètes mais dépendent d'un déploiement réel non encore fait, pas d'un développement restant :

- **F11** nécessite un projet Firebase Cloud Messaging en production (clés serveur réelles) et un webhook Odoo joignable depuis l'extérieur — impossible à opérer/tester depuis un Docker/WSL local, requiert le VPS.
- **F12** — le bouton de partage (lien placeholder, `share_plus`) reste en Phase 1 et fonctionne déjà ; seule la **réception** du deep link (ouvrir l'app depuis un lien partagé, Universal Links/App Links) est reportée : elle nécessite un domaine réel servant les fichiers d'association en HTTPS, et la publication effective de l'app sur Google Play/App Store.

Reprises dès le déploiement VPS + soumission aux stores. Voir `status-V1.md` § 1bis pour le détail de suivi.

### Images produit — S3 au déploiement VPS (décision utilisateur, 2026-07-21)

Actuellement, les images produit (`image_128`/`image_1920`) transitent en **base64 dans le JSON** des réponses (`search_read`, contrôleurs custom) et sont affichées côté app via `Image.memory(base64Decode(...))` — identifié comme un point de performance à revoir (voir `status-V1.md` § 4, audit du 2026-07-21).

**Au déploiement VPS, ces images seront hébergées sur S3.** Toute future refonte du chargement d'image doit donc viser directement une **URL S3** (champ URL côté Odoo, ou module de stockage S3 pour les attachments/champs binaires — mécanisme exact à choisir au moment du déploiement) + un vrai widget d'image réseau avec cache disque côté Flutter — **pas** une étape intermédiaire par l'endpoint local Odoo `/web/image/<model>/<id>/<field>` qu'il faudrait ensuite re-migrer.

## Exigences transversales (non négociables)

- **Sécurité** : HTTPS/TLS 1.3 obligatoire partout, PIN jamais stocké en clair (Keychain/Keystore uniquement), session expirée après 24h d'inactivité, délai progressif anti brute-force sur le PIN (1s/2s/4s/8s puis blocage après 5 échecs), endpoints publics filtrés + rate limités.
- **i18n** : toutes les chaînes externalisées, RTL complet en arabe testé sur chaque écran, formats date/heure localisés.
- **Performance** : accueil < 2s, API < 1s, app < 50 Mo.
- **Accessibilité** : police min 14px, boutons min 44px de hauteur, contraste lisible en plein soleil.
- **Gestion d'erreurs** : message clair hors-ligne, retry automatique sur échec API, aucune erreur silencieuse.

## Structure du repo

- `docs/` — specs macro et Phase 1 (voir ci-dessus).
- `mobile/` — app Flutter. Code applicatif dans `mobile/lib/` : `navigation/` (`app_router.dart` avec go_router, `main_tab_scaffold.dart`), `screens/` (un dossier par domaine fonctionnel F00-F17), `state/` (`auth_state.dart`, `ChangeNotifier` + `provider`, persisté via `shared_preferences`), `services/` (`permission_service.dart`), `errors/` (`app_error.dart`, `app_messenger.dart`, `error_state_view.dart` — voir § Gestion des erreurs), `validation/` (`validators.dart` — téléphone, PIN, requis, correspondance), `theme/` (`app_theme.dart`), `widgets/` (composants partagés : `screen_placeholder.dart`, `app_button.dart`, `pin_input_field.dart`, `delete_account_dialog.dart`), `utils/`. Traductions dans `mobile/assets/translations/` (`fr.json`, `ar.json`, format `easy_localization`).
- Les dossiers `mobile/android/` et `mobile/ios/` (scaffolding natif Flutter) ne sont **pas** générés par Claude Code — voir note ci-dessous.
- `backend/` — backend Odoo 19 + Postgres, exécuté via Docker (WSL côté utilisateur). `docker-compose.yml` (services `db` postgres:16 et `odoo` odoo:19), `config/odoo.conf`, `addons/echango_order/` (module custom — squelette pour l'instant, champs/modèles/endpoints ajoutés au fur et à mesure du branchement de chaque écran, F02 en premier). Voir § Environnement de dev — backend Odoo.

## Environnement de dev — app mobile

Le développement de `mobile/` se fait côté utilisateur sous **Windows / PowerShell** (pas bash/zsh), avec **Android Studio** installé. Toute commande shell suggérée pour `mobile/` doit être en syntaxe PowerShell, pas Unix. Équivalences utiles :

| Unix (bash/zsh) | PowerShell |
|---|---|
| `rm -rf build .dart_tool` | `Remove-Item -Recurse -Force build, .dart_tool` |
| `rm -f fichier` | `Remove-Item -Force fichier` |
| `cat fichier` | `Get-Content fichier` |
| `ls -la` | `Get-ChildItem -Force` |
| `export VAR=valeur` | `$env:VAR = "valeur"` |
| `&&` (chaînage conditionnel) | `;` (ou `&&` fonctionne aussi en PowerShell 7+) |

En cas de doute sur la disponibilité d'une syntaxe, préférer la commande PowerShell native ou l'équivalent `flutter`/`dart` multiplateforme plutôt qu'un outil Unix.

**Commandes Flutter courantes** (depuis `mobile/`) :
- `flutter pub get` — installer les dépendances (équivalent `npm install`)
- `flutter analyze` — analyse statique (équivalent `tsc`/`eslint`)
- `flutter test` — tests unitaires/widgets
- `flutter run` — lance sur l'émulateur/device par défaut
- `flutter doctor` — diagnostic de l'environnement (SDK, Android toolchain, licences)

**Permissions natives (`permission_handler`, F14)** : le package a besoin de déclarations natives que Claude Code ne peut pas ajouter (fichiers `android/`, `ios/` inexistants ici). Après `flutter create .` en local, ajouter :

- **Android** — dans `android/app/src/main/AndroidManifest.xml`, avant `<application>` :
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```
- **iOS** — dans `ios/Runner/Info.plist` :
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Echango Order utilise votre position pour pré-remplir votre adresse de livraison.</string>
  ```
- **iOS** — `permission_handler` nécessite aussi d'activer les modules de permission utilisés dans `ios/Podfile` (macros de préprocesseur `PERMISSION_LOCATION`, `PERMISSION_NOTIFICATIONS`) — se référer au README du package (`permission_handler` sur pub.dev) au moment de configurer, la syntaxe exacte peut évoluer selon la version résolue par `flutter pub get`.

Sans ces déclarations, `flutter run` peut compiler mais la demande de permission plantera ou sera silencieusement refusée au runtime.

**Important — génération des dossiers natifs** : cet environnement cloud (sandbox Claude Code) n'a pas accès au SDK Flutter/Dart (le réseau bloque `storage.googleapis.com`, d'où proviennent les artefacts Dart/Flutter), donc Claude Code ne peut ni exécuter `flutter create`, ni `flutter analyze`/`flutter run`/`flutter test` pour vérifier son propre travail sur cette partie. En conséquence, **`mobile/android/` et `mobile/ios/` n'existent pas encore** dans le repo : après avoir récupéré du code Flutter écrit par Claude Code, lancer une fois en local :
```powershell
flutter create --org com.echangoorder .
flutter pub get
flutter analyze
```
`flutter create .` sur un dossier contenant déjà un `pubspec.yaml` ajoute uniquement les dossiers de plateforme manquants (`android/`, `ios/`, etc.) sans toucher à `lib/` ni `pubspec.yaml`. Toute vérification (`analyze`, `run`, `test`) doit se faire côté utilisateur ; Claude Code ne peut relire les erreurs qu'après que l'utilisateur les colle dans la conversation.

## Environnement de dev — backend Odoo

Le backend Odoo 19 tourne via **Docker** dans **WSL** côté utilisateur (pas dans ce sandbox cloud). Tout se passe dans `backend/`.

**Premier lancement :**
```bash
cd backend
cp .env.example .env        # ajuster DB_USER/DB_PASSWORD si besoin (dev local uniquement)
docker compose up -d
```
Puis ouvrir `http://localhost:8069` — l'assistant Odoo de création de base de données s'affiche au premier accès (choisir un nom de base, un mot de passe admin, cocher "Demo data" seulement si besoin de données d'exemple pour tester). Le module custom `echango_order` (dans `backend/addons/`) apparaît dans **Apps** une fois la base créée — retirer le filtre "Apps" par défaut et chercher "Echango Order" pour l'installer (`--dev=all` ou un `-u echango_order` en ligne de commande fonctionne aussi si préféré).

**Commandes utiles :**
- `docker compose up -d` — démarre Odoo + Postgres en arrière-plan
- `docker compose logs -f odoo` — logs Odoo en continu (indispensable pour déboguer un module qui ne charge pas)
- `docker compose down` — arrête (les données restent dans les volumes Docker nommés)
- `docker compose down -v` — arrête ET supprime les volumes (repart de zéro, perd la base)
- `docker compose restart odoo` — redémarre juste Odoo après une modif du module custom (nécessaire pour recharger le code Python — un simple hot-reload n'existe pas côté Odoo)

**WSL — points d'attention :**
- Cloner le repo **dans le filesystem WSL** (`~/...` ou `/home/...`), pas sous `/mnt/c/...` — les performances de build/volume Docker sont nettement dégradées sur un chemin Windows monté.
- Docker Desktop avec l'intégration WSL2 activée (Paramètres → Resources → WSL Integration → cocher la distro utilisée), ou Docker Engine installé directement dans la distro — les deux fonctionnent, les commandes `docker compose` sont identiques.
- Si le port 8069 est déjà pris (autre projet Odoo local), changer le port publié dans `docker-compose.yml` (`"8069:8069"` → `"8070:8069"` par exemple).

**Limite d'environnement (comme pour Flutter)** : ce sandbox cloud n'a pas accès à Docker Hub (réseau bloqué, même politique que `storage.googleapis.com`), donc Claude Code ne peut ni tirer les images `odoo:19`/`postgres:16`, ni lancer de conteneur pour vérifier son propre travail. `docker-compose.yml` a été validé avec `docker compose config` (parsing/résolution complets, sans nécessiter le daemon) mais **jamais réellement exécuté** — la première vérification réelle (`docker compose up`, accès à `http://localhost:8069`, installation du module) doit se faire côté utilisateur.

## Stratégie d'implémentation en cours

Développement en deux temps, décidé pour ce projet :
1. **Écrans + navigation d'abord, sans backend** — tous les écrans F00-F17 existent en placeholders (`ScreenPlaceholder`) et sont intégralement navigables (via `go_router`), pour valider le parcours utilisateur et la structure de navigation avant toute donnée réelle. Pas de couche de mock/abstraction API — délibérément écarté pour ce projet.
2. **Branchement direct sur Odoo ensuite** — une fois les écrans stabilisés, chaque écran est rempli avec sa vraie UI + ses appels JSON-RPC Odoo, sans étape intermédiaire de mock.

L'état de session (`state/auth_state.dart`, `ChangeNotifier`) est un état **client local** (pas une simulation de backend) : nécessaire pour piloter la navigation (routes publiques vs onglets principaux, via le `redirect` de `go_router`) dès maintenant, et qui restera après le branchement Odoo — seul le contenu du login réel changera. La langue est gérée directement par `easy_localization` (`context.setLocale()`), pas de contexte custom nécessaire.

## Gestion des erreurs (convention — obligatoire pour tout nouveau code)

Toute erreur ou message affiché à l'utilisateur passe par le système centralisé dans `mobile/lib/errors/`, jamais par un `ScaffoldMessenger`/`showDialog` direct dans un écran.

- **`app_error.dart`** — classe `AppError` : une erreur = un **code** (`String`), pas un message en dur. Le code est un chemin en points qui correspond exactement à une clé dans `errors.*` des fichiers `assets/translations/*.json` (ex : code `network.offline` → traduction `errors.network.offline`). Les codes connus sont des constantes statiques sur `AppError` (`AppError.networkOffline`, `AppError.authSessionExpired`, `AppError.promoInvalid`, etc.), classées par domaine (network, server, auth, validation, checkout, promo, order, permissions).
- **`app_messenger.dart`** — classe `AppMessenger`, seul point d'affichage :
  - `AppMessenger.showError(context, error, {onRetry})` — snackbar rouge, bouton "Réessayer" optionnel.
  - `AppMessenger.showInfo(context, messageKey)` — snackbar neutre (message non-erreur, ex: "bientôt disponible").
  - `AppMessenger.showErrorDialog(context, error, {onRetry})` — dialog bloquant (erreur critique, session expirée...).
- **`error_state_view.dart`** — widget plein écran réutilisable (icône + titre + message + bouton retry) pour les états vides (panier vide, aucune commande...) et les erreurs bloquantes (ex : `MaintenanceScreen`). `ErrorStateView.forError(error, {onRetry})` construit l'état directement depuis un `AppError`.

**Pourquoi des codes et pas des messages en dur** : un·e traducteur·rice ne touche que les fichiers JSON, jamais le code Dart. Et surtout, ça prépare le branchement Odoo (F02+) : les erreurs JSON-RPC d'Odoo (`error.data.name`, codes HTTP, etc.) devront être mappées vers ces mêmes constantes `AppError.*` dans la couche d'appel API, sans toucher à l'affichage ni aux traductions déjà en place. Si un nouveau cas d'erreur apparaît côté Odoo sans code `AppError` correspondant, ajouter la constante + les 2 traductions (fr/ar) avant de l'utiliser.

## Traductions (i18n) — vérification automatisée

Toute chaîne affichée à l'utilisateur passe par `easy_localization` (`'clé'.tr()`), jamais de texte en dur — y compris les préfixes de labels (ex: `common.reference` pour "Réf :", pas juste `Text('Réf : $x')`). Seules exceptions tolérées : libellés techniques de debug (`productId: $id`, disparaîtront avec les vraies données Odoo) et noms de langue dans le sélecteur de langue ("Français"/"العربية" — ne se traduisent pas par définition).

`mobile/test/translations_completeness_test.dart` est le point centralisé pour détecter des traductions manquantes — à lancer après tout ajout d'écran ou de clé i18n :
```powershell
flutter test test/translations_completeness_test.dart
```
Il vérifie trois choses : (1) `fr.json` et `ar.json` ont exactement les mêmes clés (pas de dérive entre les deux langues), (2) toute clé statique `'x.y.z'.tr()` utilisée dans `lib/` existe bien dans les deux fichiers, (3) tout `screenKey` passé à `ScreenPlaceholder` a bien un `title` + `subtitle` en FR et en AR. Si le test échoue, le message d'erreur liste exactement les clés manquantes.

**Si du texte reste en français en mode AR malgré ce test qui passe** : ce n'est pas un problème de traduction manquante mais probablement un souci de rebuild — les fichiers JSON sont des *assets* embarqués au build, un hot reload ne les recharge pas toujours. Faire un arrêt complet + `flutter run` (pas juste hot reload/hot restart) avant de considérer que c'est un bug.

**`PlaceholderAction.label` (`widgets/screen_placeholder.dart`) est un `String Function()`, jamais une `String` déjà résolue** — bug trouvé par l'utilisateur (2026-07-20) : les boutons de la page Profil restaient dans l'ancienne langue après changement de langue. Cause : `'clé'.tr()` appelé une fois dans le `build()` de l'écran *appelant* (ex. `ProfileScreen`) fige la chaîne au moment de la construction. Toujours écrire `label: () => 'clé'.tr()` (jamais `label: 'clé'.tr()`), y compris pour les deux libellés non traduits par exception ("Français"/"العربية" → `() => 'Français'`) — la fonction est appelée à l'intérieur de `ScreenPlaceholder.build()`, au même endroit que le titre.

**`context.setLocale()` seul ne suffit pas à rafraîchir les pages déjà montées dans la barre de navigation à onglets** — creusé après le correctif ci-dessus (l'utilisateur a signalé que les boutons de Profil restaient bloqués malgré tout, et que la barre du bas ne se mettait à jour qu'après un changement d'onglet). Cause : `StatefulShellRoute` garde chaque onglet vivant via un `IndexedStack` — ces pages déjà montées ne sont pas reconstruites par le mécanisme de dépendance interne d'easy_localization dans ce contexte, seule une navigation (changement d'onglet) force `go_router` à les reconstruire. Plutôt que de recharger toute l'app (perte de la pile de navigation), `state/locale_state.dart` (`LocaleState`, un `ChangeNotifier` comme `CartState`/`AuthState`) force un rebuild ciblé : `LanguageSettingsScreen` appelle `context.read<LocaleState>().notifyLocaleChanged()` juste après `await context.setLocale(...)`, et `ScreenPlaceholder`/`MainTabScaffold`/`HomeScreen` (les points touchés par le bug + l'autre racine d'onglet gardée vivante) appellent `context.watch<LocaleState>()` en tête de leur `build()`. Tout nouvel écran gardé vivant dans la barre de navigation à onglets (actuellement Accueil/Profil) qui affiche du texte traduit statique doit faire de même.

## Principe architecture Odoo — standard avant custom

**Règle non négociable pour tout développement backend : s'appuyer au maximum sur les modèles, champs et mécanismes standards d'Odoo** (logiciel stable depuis des années) plutôt que de recréer une couche custom. Un ajout custom (nouveau modèle, nouveau champ `x_*`, nouveau contrôleur HTTP) n'est justifié que lorsqu'Odoo standard **n'a aucun équivalent** pour le besoin — à vérifier explicitement avant toute création, et à documenter ici.

Conséquences déjà actées pour Echango Order :

- **Identité client = utilisateur portail Odoo** (`res.users` + groupe `base.group_portal`, lié à un `res.partner`), pas un modèle custom séparé. On réutilise ainsi le modèle de sécurité (record rules) et la compatibilité `/web/dataset/call_kw` déjà fournis par Odoo pour les utilisateurs portail, plutôt que de coder des contrôleurs custom pour tout le CRUD client.
- **Champs standards réutilisés tels quels** (pas de doublon `x_*`) :
  - Langue → `res.partner.lang` (champ standard, sélection des langues installées) — **remplace `x_langue`**, retiré de la liste ci-dessous.
  - Téléphone → `res.partner.phone` — pas de champ custom dédié. **Odoo 19 a fusionné `mobile` dans `phone`** (le champ `mobile` n'existe plus sur `res.partner` depuis cette version, confirmé en testant contre une instance réelle) : ne pas utiliser `mobile`, il n'existe plus.
  - Adresse de livraison → adresses enfants standards de `res.partner` (mécanisme multi-adresses natif, `type='delivery'`) plutôt qu'un champ texte libre. `x_adresse_favorite` implémenté (F10) exactement comme prévu ici : un simple booléen sur `res.partner` (`models/res_partner.py`), une seule adresse favorite à la fois par client (contrôleur `sudo()` qui désactive les autres favoris du même parent à l'écriture) — pas de réécriture de l'adresse.
  - Commandes → `sale.order` standard (statuts, lignes, `partner_id`) plutôt qu'un modèle de commande custom.
  - Coordonnées GPS → `res.partner.partner_latitude`/`partner_longitude` — **champs standards du module `base` lui-même** (pas besoin du module `base_geolocalize`, qui ne fait qu'ajouter un bouton de géocodage automatique ; les champs existent nativement, confirmé contre le code source Odoo 19). **Remplace `x_latitude`/`x_longitude`**, retirés de la liste ci-dessous.
- **Modèle `x_rate_limit`** (compteur anti-abus par IP, `models/rate_limit.py`) : Odoo n'a pas de rate limiting HTTP intégré pour des contrôleurs custom — champ/modèle custom justifié, purgé quotidiennement par un `ir.cron` standard (`data/rate_limit_data.xml`) plutôt qu'un mécanisme de nettoyage maison.
- **Modèle `x_timeslot_capacity`** (capacité par créneau/mode de réception, `models/timeslot_capacity.py`) : aucune notion de créneau/capacité nativement en Odoo 19 CE — modèle custom justifié. Les créneaux eux-mêmes restent générés côté client (`mobile/lib/utils/timeslots.dart`, seule source de vérité pour les horaires), ce modèle ne fait que déclarer un maximum de commandes par heure — voir § Sécurité/`controllers/checkout_controller.py` (`timeslots`/`_slot_is_full`).
- **Modèle `x_pin_reset_wizard`** (assistant "Réinitialiser le PIN" sur la fiche utilisateur, `models/pin_reset_wizard.py`) : Odoo n'a pas de notion de PIN (voir `x_pin` ci-dessous) donc pas de flux de réinitialisation associé — `TransientModel` standard (assistant, purgé automatiquement par le mécanisme natif d'Odoo) plutôt qu'un modèle persistant custom. F02 "PIN oublié" : aucun fournisseur SMS choisi, donc pas de libre-service — la demande crée une activité pour un modérateur (même mécanisme que la validation de compte, `res_partner._notify_pin_reset_requested`), qui recontacte le client par téléphone et utilise cet assistant.
- **Modèle `x_substitute_product_ids`** (Many2many sur `product.template`, `models/product_template.py`) : produits de substitution (voir § Produits de substitution ci-dessous) — module OCA `stock_picking_product_interchangeable` vérifié avant création (recherche faite, pas supposée) mais ne convient pas, voir cette section.
- **Champs sans équivalent standard, donc custom, restent justifiés** : `x_pin` (hashé, sur `res.users` — aucune notion de PIN dans Odoo, l'auth standard est login/mot de passe), `x_reception_mode`, `x_creneau`, `x_firebase_token`, `x_vitrine_publique`, `x_verification_state` (voir § Qualité clients ci-dessous), `x_last_activity` (Datetime sur `res.users` — `login_date` standard n'est mis à jour qu'à la connexion, pas à chaque appel API ; nécessaire pour la politique "session expirée après 24h d'inactivité", voir § Sécurité/`controllers/session_utils.py`), modèle `x_delivery_zone` (pas de notion de zone de livraison simple nativement en Odoo 19 CE), modèle `x_product_favorite` (voir § Favoris ci-dessous).

## Favoris (décision produit, hors périmètre specs initiales)

**Décision produit (2026-07, suite à échange avec l'utilisateur)** : liste de produits favoris par client, initialisée automatiquement par l'historique de commandes (dédupliqué) puis modifiable manuellement (ajout/retrait) — contrairement à "favoris" listé comme hors périmètre Phase 1 dans les specs (§5), cette version simplifiée (pas de filtres avancés, pas de partage) a été explicitement demandée et implémentée.

- Modèle `x_product_favorite` (`partner_id`, `product_tmpl_id`, contrainte unique) — aucun équivalent standard sans le module `website_sale` (non installé), qui a son propre modèle `product.wishlist` mais nécessite l'app eCommerce entière.
- Initialisation automatique dans `models/sale_order.py` (`SaleOrder.action_confirm()`/`_seed_favorites()` — déplacé depuis `checkout_controller.py` lors de la refonte des statuts de commande, voir § Statuts de commande ci-dessous) : chaque produit d'une commande confirmée est ajouté aux favoris s'il n'y est pas déjà (lignes de récompense/réduction exclues).
- Gestion manuelle via `controllers/favorites_controller.py` (`/echango/favorites`, `/add`, `/remove`) — écran dédié `FavoritesScreen` (Profil), avec un écran de recherche pour ajouter d'autres produits.

## Qualité clients — vérification manuelle des nouveaux comptes

**Décision produit (2026-07)** : plutôt que de choisir un service de géocodage externe pour valider automatiquement les adresses/comptes, un modérateur valide **manuellement** chaque nouveau compte client depuis le back-office Odoo avant qu'il puisse passer commande.

- `res.partner.x_verification_state` (Selection : `pending`/`verified`/`rejected`) — défaut `verified` au niveau du champ (pour ne pas affecter les partenaires déjà en base : adresses de livraison enfants, fournisseurs, contacts internes...), positionné explicitement à `pending` **uniquement** par `/echango/auth/register` sur un nouveau compte client.
- Fiche contact standard (`base.view_partner_form`) enrichie d'un statusbar + boutons "Valider"/"Rejeter" (`views/res_partner_views.xml`), plus un menu "Clients à valider" (Echango Order) filtré sur les comptes portail non vérifiés.
- Vérifié au moment de `/echango/checkout/confirm` (la seule action qui compte réellement) — un compte `pending`/`rejected` ne peut pas confirmer de commande. L'app avertit aussi dès l'écran Panier (`verification_state` renvoyé par `_cart_payload`) pour éviter de faire remplir tout le tunnel checkout pour rien, mais la vérification faisant foi reste côté serveur.

## Statuts de commande (F08 — décision produit, 2026-07)

**Décision produit (2026-07, suite à échange avec l'utilisateur)** : le cycle de vie d'une commande côté client passe par 5 étapes, quasi entièrement portées par des mécanismes standards Odoo :

1. **Panier** — `sale.order.state == 'draft'`, inchangé.
2. **En attente de prise en charge** — le client "confirme sa commande" dans l'app (bouton du tunnel checkout), mais la commande **reste modifiable** : le client peut continuer à ajouter des produits depuis le catalogue. Réutilise `state == 'sent'` ("Devis envoyé"), valeur **déjà standard** dans le Selection `state` de `sale.order`, jusqu'ici jamais utilisée par ce module — juste relabellée (`selection_add=[('sent', 'En attente de prise en charge')]` dans `models/sale_order.py`), aucun nouveau champ. `checkout_controller.py.confirm()` écrit directement `state = 'sent'` (pas d'appel à `action_quotation_sent()`, qui ouvre l'assistant d'envoi par email — pensé pour l'interaction humaine back-office, pas pour un simple changement d'état déclenché par l'app). `cart_controller.py` (`_cart_order`/`_owned_line`) étend son domaine de mutation à `draft`/`sent` : le panier "courant" d'un client reste le même enregistrement tant qu'un opérateur ne l'a pas pris en charge.
3. **En préparation** — l'opérateur "prend" la commande en cliquant sur le bouton **"Confirmer" déjà standard** du formulaire de devis Odoo (`action_confirm()`, `sent` → `sale`) — aucun bouton custom ajouté pour cette étape. Dès ce moment, `sale.order`/`sale.order.line` redeviennent inaccessibles en écriture au portail (comportement déjà en place) et le `stock.picking` (bon de livraison) est généré automatiquement par Odoo, avec réservation de stock **automatique/immédiate** (décision produit délibérée — voir point de vigilance ci-dessous, pour éviter les commandes annulées faute de stock).
4. **En cours de préparation** — un opérateur a commencé à traiter concrètement la commande. Avec la réservation automatique (point 3), le picking passe de "En attente" à "Prêt" quasi instantanément dès qu'il y a du stock — l'état du picking seul ne dit donc rien sur si quelqu'un a commencé à s'en occuper. Plutôt qu'un champ custom, réutilisation du champ **standard** `stock.picking.user_id` (Responsable, natif, jamais rempli automatiquement à la création) : un opérateur qui s'assigne le bon signale qu'il le traite. `order_controller.py._prep_status()` renvoie `in_progress` quand le picking est `assigned` **et** `user_id` renseigné (sinon `pending`, quel que soit l'état de réservation).
5. **Prête** — le bon de livraison est validé (`stock.picking.state == 'done'`) — `order_controller.py._prep_status()` renvoie `completed`. **Ne veut pas dire "remise au client"**, ni pour la livraison à domicile ni pour le retrait magasin (voir points 6 et 7 ci-dessous — cette phrase disait initialement le contraire pour le retrait magasin, corrigé suite à un bug signalé par l'utilisateur : un bon WH/OUT validé faisait passer l'app directement à "Récupérée" sans état intermédiaire).
6. **Livraison à domicile uniquement : en cours de livraison → livrée** — aucun équivalent standard sans intégration transport réelle (GPS, app dédiée — hors périmètre Phase 1, cf. §5). Nouveau champ `x_delivery_status` (Selection `out_for_delivery`/`delivered`) sur `sale.order`, avec 2 boutons back-office (`action_mark_out_for_delivery`/`action_mark_delivered`, `views/sale_order_views.xml`, visibles uniquement pour `x_reception_mode == 'home_delivery'`) — statut déclaré manuellement, pas de vrai tracking. **Option alternative envisagée et écartée** : configurer une livraison Odoo standard en 2 étapes (Colis + Livraison), qui aurait évité tout champ custom — écartée car elle demande une route de livraison différenciée du retrait magasin (qui doit rester en 1 étape), et l'état "Prêt" du 2e bon ne correspond pas vraiment à "le camion est parti", juste "chargé en zone de sortie".
7. **Retrait en magasin uniquement : prête à récupérer → récupérée** — même problème que le point 6, signalé par l'utilisateur après un test réel (bon WH/OUT validé en Odoo, l'app passait directement à "Récupérée" sans état intermédiaire "Prête à récupérer"). Nouveau champ `x_pickup_collected` (Boolean, `sale.order`) avec 1 bouton back-office (`action_mark_picked_up`, `views/sale_order_views.xml`, visible uniquement pour `x_reception_mode == 'pickup'` et pas déjà coché) — un seul booléen suffit ici (contrairement à la livraison, pas d'étape "en route" pertinente pour un retrait en magasin). Côté app, `prepStatusLabel()` renvoie `order.prepReadyPickup` ("Prête à récupérer") tant que `x_pickup_collected` est `false`, puis `order.prepCompletedPickup` ("Récupérée") une fois coché.

Côté app, `mobile/lib/utils/order_status.dart` (`prepStatusLabel()`) centralise la résolution de ces libellés (réutilisé par l'historique F09 et le suivi F08).

**Point de vigilance tranché (2026-07, discussion avec l'utilisateur)** : la réservation de stock automatique à la confirmation (étape 3) est un choix assumé — sans elle, deux clients pourraient confirmer une commande sur le même produit avant qu'aucune des deux ne soit réellement bloquée par le stock, menant à des annulations après coup. Le compromis (réservation immédiate mais pas de bouton "Vérifier la disponibilité" visible/utile) a été discuté explicitement avec l'utilisateur, qui a confirmé préférer garder le stock protégé plutôt qu'un palier "en attente de stock" manuel — d'où le recours à `stock.picking.user_id` pour l'étape 4 plutôt qu'à la désactivation de la réservation automatique.

**F16 (annulation) — revu à 2 reprises** : un bug signalé par l'utilisateur (bouton "Annuler" affiché même pour une commande déjà livrée, `state` ne se remettant plus à jour après la prise en charge) a été l'occasion de retrancher le bon critère, une première fois puis ajusté à l'introduction de `in_progress`. Annulable pendant `sent` (en attente de prise en charge) **et** pendant `sale` tant que `prep_status` n'est pas encore `completed` (en préparation, y compris "en cours" — un opérateur qui a commencé peut toujours reposer les articles) — bloqué dès que la commande est prête, peu importe la suite (prête/en cours de livraison/livrée-récupérée, toutes trop tard). `order_controller.py._can_cancel()` (vérification qui compte) + même logique dupliquée côté `order_tracking_screen.dart` pour l'affichage du bouton.

## Produits de substitution (F17 — décision produit revue, 2026-07)

**Décision produit (2026-07, suite à échange avec l'utilisateur, remplace l'implémentation F17 initiale)** : en cas de rupture de stock, c'est **toujours le client** qui choisit un produit de remplacement — jamais le préparateur. L'ancienne implémentation F17 (préparateur choisit un substitut au cas par cas en back-office après confirmation de la commande, `x_substitution_produit` sur `sale.order.line`) est **supprimée** : plus de flux post-confirmation (`SubstitutionScreen`, endpoints `/echango/order/substitution*` retirés).

Avant de créer un champ custom, le module OCA gratuit `stock_picking_product_interchangeable` (dépôt `stock-logistics-warehouse`) a été vérifié (recherche faite explicitement, pas supposée) : relation "interchangeable" Many2many curée par l'admin sur le produit — même forme que ce qui suit — mais substitution **automatique** côté `stock.picking` sans interaction client, et relation **symétrique** (A substitue B implique B substitue A). Ne convient pas : ici c'est le client qui choisit, jamais le système, et la relation est volontairement asymétrique.

- **Modèle `x_substitute_product_ids`** (Many2many self-référentiel sur `product.template`, `models/product_template.py`, relation/colonnes explicites) : liste de produits de substitution, curée manuellement par l'admin en back-office (`views/product_template_views.xml`, widget `many2many_tags`) — jamais générée automatiquement, jamais choisie par le préparateur.
- **Fiche produit (F05)** : section "Produits de substitution" affichée si le produit en a (`/echango/catalog/substitutes`, résolution nom/prix/image/stock en `sudo()`, même pattern que `stock()`/`promotions()` dans `catalog_controller.py`) — le client les découvre en amont, en composant sa commande.
- **Au checkout (F07)** : `checkout_controller.py.confirm()` ne bloque plus sur un message générique dès la première ligne en rupture — toutes les lignes indisponibles sont remontées d'un coup (`{"error": "cart.unavailable_products", "unavailable_lines": [...]}`), chacune avec ses substituts pré-définis (filtrés `sale_ok` + en stock) et sa quantité. Côté app, `CartUnavailableProductsError` (étend `AppError`, porte la liste — voir `errors/app_error.dart`) est interceptée avant le mapping d'erreur générique dans `OdooApiClient.confirmOrder()`, et ouvre `CheckoutResolveUnavailableScreen` : pour chaque ligne, le client choisit un substitut ou supprime la ligne (endpoints panier existants, `cart/remove` + `cart/add` — pas de contrôleur dédié), puis la confirmation est retentée automatiquement.

## Custom fields Odoo attendus (Expert Odoo)

`x_reception_mode`, `x_creneau`, `x_firebase_token`, `x_vitrine_publique`, `x_pin` (hashé, sur `res.users`), `x_adresse_favorite` (booléen sur `res.partner`, implémenté F10 — voir ci-dessus), `x_verification_state` (Selection sur `res.partner`, implémenté — voir § Qualité clients ci-dessus), `x_last_activity` (Datetime sur `res.users`, implémenté — session 24h d'inactivité, voir § Principe architecture Odoo ci-dessus), modèle `x_delivery_zone`, modèle `x_rate_limit` (compteur anti-abus à fenêtre fixe par IP, implémenté — endpoints publics rate limités, voir § Sécurité/`controllers/rate_limit.py`), modèle `x_timeslot_capacity` (capacité par créneau/mode de réception, implémenté — voir ci-dessus), modèle `x_pin_reset_wizard` (assistant de réinitialisation du PIN par un modérateur, implémenté — voir ci-dessus), modèle `x_substitute_product_ids` (produits de substitution curés par l'admin, implémenté — voir § Produits de substitution ci-dessus), `x_delivery_status` (Selection sur `sale.order`, implémenté — statut de livraison à domicile déclaré manuellement, voir § Statuts de commande ci-dessus), `x_pickup_collected` (Boolean sur `sale.order`, implémenté — statut de retrait magasin déclaré manuellement, voir § Statuts de commande ci-dessus).

~~`x_langue`~~ : supprimé, remplacé par le champ standard `res.partner.lang` (voir § Principe architecture Odoo ci-dessus).

~~`x_latitude`/`x_longitude`~~ : supprimés, remplacés par les champs standards `res.partner.partner_latitude`/`partner_longitude` (voir § Principe architecture Odoo ci-dessus).

~~`x_substitution_produit`~~ : supprimé (F17 initial, préparateur choisit après confirmation), remplacé par `x_substitute_product_ids` (voir § Produits de substitution ci-dessus) — c'est désormais toujours le client qui choisit.

## Documentation

- `docs/specs_macro_drive_transport.md` — vision produit globale (Echango Order + Echango Delivery), roadmap macro, architecture Odoo ↔ Fleetbase.
- `docs/specs_phase1_echango_order.md` — specs détaillées Phase 1 (wireframes, API, critères d'acceptation QA par fonctionnalité).
- `docs/design_direction.md` — direction visuelle retenue (**Casbah**, décision 2026-07-20) : palette, typographie FR/AR, langage de formes, plan de mise à jour du thème par phases. Les deux pistes non retenues (Souk, Zellige) y sont archivées pour référence future.
- `status-V1.md` — suivi de l'avancement de l'implémentation Phase 1, à tenir à jour à chaque étape.

## Conventions de travail

- Développer sur la branche dédiée à la tâche en cours, jamais directement sur `main`.
- Mettre à jour `status-V1.md` à chaque fonctionnalité livrée ou changement d'état significatif.
- Respecter les critères d'acceptation QA de chaque fonctionnalité (checklists dans les specs Phase 1) avant de la considérer terminée.
- Tout nouveau champ custom Odoo doit être documenté et validé contre la liste ci-dessus avant création.
- Tout message d'erreur ou d'information affiché à l'utilisateur passe par `AppMessenger`/`ErrorStateView` (voir § Gestion des erreurs) — jamais de `ScaffoldMessenger`/`showDialog` direct dans un écran, jamais de message en dur non traduit.
