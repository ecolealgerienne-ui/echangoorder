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
- **Auth** : téléphone + PIN 4 chiffres (endpoint custom Odoo, PIN hashé, stockage device via iOS Keychain / Android Keystore)

> **Note** : les specs (`docs/specs_phase1_echango_order.md`, `docs/specs_macro_drive_transport.md`) mentionnent React Native comme stack d'origine. Décision prise en cours de projet de basculer sur **Flutter** (choix de l'équipe, expérience Flutter préalable). Cette section fait foi pour le choix technique actuel ; les specs restent la référence fonctionnelle (écrans, parcours, API, critères QA), inchangée par ce changement de framework. Un premier projet React Native a existé brièvement dans `mobile/` avant d'être remplacé — historique consultable dans le log git si besoin.

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

## Exigences transversales (non négociables)

- **Sécurité** : HTTPS/TLS 1.3 obligatoire partout, PIN jamais stocké en clair (Keychain/Keystore uniquement), session expirée après 24h d'inactivité, délai progressif anti brute-force sur le PIN (1s/2s/4s/8s puis blocage après 5 échecs), endpoints publics filtrés + rate limités.
- **i18n** : toutes les chaînes externalisées, RTL complet en arabe testé sur chaque écran, formats date/heure localisés.
- **Performance** : accueil < 2s, API < 1s, app < 50 Mo.
- **Accessibilité** : police min 14px, boutons min 44px de hauteur, contraste lisible en plein soleil.
- **Gestion d'erreurs** : message clair hors-ligne, retry automatique sur échec API, aucune erreur silencieuse.

## Structure du repo

- `docs/` — specs macro et Phase 1 (voir ci-dessus).
- `mobile/` — app Flutter. Code applicatif dans `mobile/lib/` : `navigation/` (`app_router.dart` avec go_router, `main_tab_scaffold.dart`), `screens/` (un dossier par domaine fonctionnel F00-F17), `state/` (`auth_state.dart`, `ChangeNotifier` + `provider`, persisté via `shared_preferences`), `services/` (`permission_service.dart`), `theme/` (`app_theme.dart`), `widgets/` (composants partagés : `screen_placeholder.dart`, `app_button.dart`, `delete_account_dialog.dart`), `utils/`. Traductions dans `mobile/assets/translations/` (`fr.json`, `ar.json`, format `easy_localization`).
- Les dossiers `mobile/android/` et `mobile/ios/` (scaffolding natif Flutter) ne sont **pas** générés par Claude Code — voir note ci-dessous.

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

## Stratégie d'implémentation en cours

Développement en deux temps, décidé pour ce projet :
1. **Écrans + navigation d'abord, sans backend** — tous les écrans F00-F17 existent en placeholders (`ScreenPlaceholder`) et sont intégralement navigables (via `go_router`), pour valider le parcours utilisateur et la structure de navigation avant toute donnée réelle. Pas de couche de mock/abstraction API — délibérément écarté pour ce projet.
2. **Branchement direct sur Odoo ensuite** — une fois les écrans stabilisés, chaque écran est rempli avec sa vraie UI + ses appels JSON-RPC Odoo, sans étape intermédiaire de mock.

L'état de session (`state/auth_state.dart`, `ChangeNotifier`) est un état **client local** (pas une simulation de backend) : nécessaire pour piloter la navigation (routes publiques vs onglets principaux, via le `redirect` de `go_router`) dès maintenant, et qui restera après le branchement Odoo — seul le contenu du login réel changera. La langue est gérée directement par `easy_localization` (`context.setLocale()`), pas de contexte custom nécessaire.

## Custom fields Odoo attendus (Expert Odoo)

`x_reception_mode`, `x_creneau`, `x_firebase_token`, `x_vitrine_publique`, `x_pin` (hashé), `x_langue`, `x_latitude`, `x_longitude`, `x_adresse_favorite`, `x_substitution_produit`, modèle `x_delivery_zone`.

## Documentation

- `docs/specs_macro_drive_transport.md` — vision produit globale (Echango Order + Echango Delivery), roadmap macro, architecture Odoo ↔ Fleetbase.
- `docs/specs_phase1_echango_order.md` — specs détaillées Phase 1 (wireframes, API, critères d'acceptation QA par fonctionnalité).
- `status-V1.md` — suivi de l'avancement de l'implémentation Phase 1, à tenir à jour à chaque étape.

## Conventions de travail

- Développer sur la branche dédiée à la tâche en cours, jamais directement sur `main`.
- Mettre à jour `status-V1.md` à chaque fonctionnalité livrée ou changement d'état significatif.
- Respecter les critères d'acceptation QA de chaque fonctionnalité (checklists dans les specs Phase 1) avant de la considérer terminée.
- Tout nouveau champ custom Odoo doit être documenté et validé contre la liste ci-dessus avant création.
