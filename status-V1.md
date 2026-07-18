# Status V1 — Echango Order (MVP Phase 1)

Suivi de l'avancement de l'implémentation. Statuts : `Non démarré` · `En cours` · `Bloqué` · `Terminé`.

Dernière mise à jour : 2026-07-18

**Stratégie en cours** : phase 1 = écrans + navigation complets, sans données ni backend (état local simulé uniquement pour piloter la navigation : session auth). Phase 2 = branchement direct sur Odoo (pas de couche mock intermédiaire).

**⚠️ Changement de stack (2026-07-18)** : le projet a démarré en React Native puis a été **entièrement basculé sur Flutter** en cours de route (choix de l'équipe, expérience Flutter préalable). Tout le code React Native a été supprimé et réécrit en Flutter/Dart — même périmètre fonctionnel (F00-F17), mêmes clés i18n, même logique de navigation, portés dans un nouveau framework. Voir CLAUDE.md § Stack technique pour la note de décision.

**⚠️ Changement PIN (2026-07-18)** : les specs prévoient un PIN à 4 chiffres partout ; décision produit de passer à **6-12 chiffres** (plus d'entropie). Voir CLAUDE.md § Stack technique.

---

## 0. Setup projet

| Tâche | Statut | Notes |
|---|---|---|
| Repo Git créé (`main` + branche de travail) | Terminé | Repo initialisé, docs ajoutés |
| Specs macro & Phase 1 versées dans `docs/` | Terminé | `docs/specs_macro_drive_transport.md`, `docs/specs_phase1_echango_order.md` |
| `CLAUDE.md` rédigé | Terminé | |
| Scaffolding app Flutter | Terminé | `mobile/`, `pubspec.yaml` + `lib/` écrits par Claude Code. `android`/`ios` générés côté utilisateur via `flutter create --org com.echangoorder .` |
| Navigation (go_router : routes publiques + StatefulShellRoute tabs) | Terminé — `flutter analyze` OK | Tous les écrans F00-F17 navigables de bout en bout (`mobile/lib/navigation/app_router.dart`). `flutter analyze` passé côté utilisateur (2 warnings cosmétiques corrigés : import inutile, doc comment) |
| Config i18n FR/AR + RTL | Terminé (base) | `easy_localization`, fichiers `assets/translations/fr.json`/`ar.json`. RTL géré nativement par Flutter (`Directionality` auto sur `Locale('ar')`) — pas de redémarrage app nécessaire contrairement à React Native. Reste à valider visuellement sur device/émulateur |
| État local (session, onboarding) pour piloter la navigation | Terminé | `state/auth_state.dart` (`ChangeNotifier` + `provider`), branché sur le `redirect` de `go_router`, **persisté via `shared_preferences`** (survit au redémarrage de l'app) — sera remplacé par la vraie session Odoo (F02) |
| F14 — Permissions natives réelles (GPS, notifications) | Terminé (code) | `permission_handler` : dialog d'explication + demande système, gestion du refus sans bloquer l'app. **Déclarations natives Android (`AndroidManifest.xml`) et iOS (`Info.plist`/`Podfile`) pas encore ajoutées** — voir CLAUDE.md, à faire après génération de `android/`/`ios/` |
| F17 — Écran substitution produit | Terminé | Accessible via bouton démo depuis le suivi de commande (pas de vrai trigger tant que F11 n'existe pas) |
| F12 — Bouton partage produit | Terminé (partiel) | `share_plus`, sheet natif avec lien placeholder. Réception du deep link non câblée (nécessite domaine + choix de techno, cf. §4) |
| F10 — Suppression de compte (popup + PIN) | Terminé (UI) | `delete_account_dialog.dart` — saisie 6-12 chiffres via `PinInputField`, aucune validation réelle du PIN contre un compte (attend Odoo) |
| Nouvelles dépendances (`permission_handler`, `share_plus`, `shared_preferences`) | Terminé — `flutter analyze` OK | Corrigé suite au 1er `flutter analyze` local : `SharePlus.instance.share(ShareParams(...))` n'existait pas dans la version résolue → remplacé par `Share.share(text)` (API historique, stable). `test/widget_test.dart` généré par `flutter create .` référençait l'ancien template (`MyApp`) → réécrit pour pointer sur `EchangoOrderApp` avec `SharedPreferences.setMockInitialValues({})` |
| Gestion d'erreurs centralisée (codes + i18n) | Terminé (infra) | `lib/errors/` : `AppError` (codes en dot-path mappés 1:1 sur `errors.*` dans les traductions), `AppMessenger` (seul point d'affichage : snackbar erreur/info, dialog bloquant), `ErrorStateView` (état plein écran réutilisable, vides + erreurs). Tous les `ScaffoldMessenger`/messages en dur existants migrés (`coming_soon.dart`, `permission_service.dart`, `MaintenanceScreen`). Convention documentée dans CLAUDE.md — **obligatoire pour tout nouveau code**, y compris le futur client Odoo (mapper les erreurs JSON-RPC vers ces mêmes codes) |
| Validation de formulaire centralisée | Terminé (infra) | `lib/validation/validators.dart` : `validatePhone`, `validatePin` (6-12 chiffres), `validateRequired`, `validatePinMatch` — retournent des `AppError?`, affichées via `AppMessenger` |
| Champ PIN réutilisable | Terminé | `widgets/pin_input_field.dart` — masqué, bascule visibilité, 6-12 chiffres. Câblé (vrais champs + validation) dans Login, RegisterStep1 (téléphone) et RegisterStep3, ChangePin, ForgotPin, DeleteAccount. Aucune vérification contre un vrai compte (attend Odoo) |
| États vides (Cart, OrderHistory, Search) | Terminé | `ErrorStateView` appliqué aux 3 écrans (specs QA : panier vide, aucune commande — avec message spécifique invité, aucun résultat recherche). Boutons démo conservés pour continuer à tester la navigation checkout/suivi/fiche produit tant qu'il n'y a pas de vraies données |
| Numéro de version dans "À propos" | Terminé | `package_info_plus`, F14 QA "Numéro de version visible et à jour" |
| Vérification automatisée des traductions FR/AR | Terminé | `test/translations_completeness_test.dart` — audit demandé suite à un signalement "traductions AR manquantes" (titre "Mon Panier", plusieurs boutons). Audit complet effectué (clés `.tr()` statiques + tous les `screenKey` × title/subtitle) : **aucune clé manquante trouvée** dans le code actuel, fr.json et ar.json parfaitement synchronisés. Seul écart réel trouvé et corrigé : 2 labels "Réf :" en dur (→ `common.reference`). Le signalement initial est probablement un souci de rebuild (assets JSON non rechargés en hot reload) plutôt qu'une vraie traduction manquante — ce test tourne maintenant en continu pour objectiver ça à l'avenir |
| Environnement Odoo 19 + Postgres (Docker/WSL) | Terminé — exécuté et validé côté utilisateur | `backend/docker-compose.yml` (odoo:19 + postgres:16), `backend/config/odoo.conf`, module `backend/addons/echango_order/`. `docker compose up` réel effectué en WSL, base créée, module installé/mis à niveau avec succès. Voir CLAUDE.md § Environnement de dev — backend Odoo |
| Module Odoo F02 — auth téléphone/PIN | Terminé (code) — inscription et connexion validées en réel | `backend/addons/echango_order/` : `models/res_users.py` (champs `x_pin` haché, `x_pin_fail_count`, `x_pin_locked_until` sur `res.users` — voir CLAUDE.md § Principe architecture Odoo), `controllers/auth_controller.py` (`/echango/auth/register`, `/echango/auth/login`). Identité client = utilisateur portail Odoo (`base.group_portal`) lié à un `res.partner`, pas de modèle custom séparé. Connexion branchée sur le point d'extension standard `res.users._check_credentials` (type `pin`, mécanisme utilisé par `auth_oauth`/`auth_ldap`). **Testé en réel via curl contre un Odoo 19 réellement lancé (WSL)** : `/register` puis `/login` retournent `{"success": true, ...}` — 3 aller-retours nécessaires pour corriger des changements internes Odoo 19 découverts en testant (signature de `session.authenticate(env, credential)`, `res.partner.mobile` renommé `phone`, `res.users.groups_id` renommé `group_ids`), tous corrigés et confirmés contre le code source officiel d'Odoo 19. Délai anti brute-force implémenté en fenêtre `locked_until` (pas de `time.sleep`) : 1/2/4/8s puis **15 min de blocage au 5e échec — durée arbitraire, à valider avec le PO** — mécanisme codé mais le scénario de verrouillage (5 échecs consécutifs) n'a pas encore été testé en réel |
| Client API JSON-RPC Odoo (Flutter) | Terminé (F02) — **validé en réel par l'utilisateur** (inscription + connexion via l'app, sans erreur) | `lib/services/odoo_api_client.dart` (`register`/`login`, appelle `/echango/auth/*`, cookie de session Odoo gardé en mémoire) + `lib/config/api_config.dart` (URL de base dev, `10.0.2.2` sur émulateur Android). Branché sur `LoginScreen` et `RegisterStep3Screen` (le téléphone saisi à l'étape 1 transite via `extra` de go_router jusqu'à l'étape 3 pour l'appel `register`). Toutes les constantes `AppError` nécessaires existaient déjà (`authInvalidCredentials`, `authPhoneAlreadyUsed`, `authPinLocked`, `validationRequired`, `validationInvalidPin`) — mappage fait dans `odoo_api_client.dart`, aucune traduction à ajouter. Logs backend confirment aussi le délai anti brute-force (tentatives PIN incorrectes court-circuitées par la fenêtre `locked_until` sans même atteindre `res.users.authenticate`). **Limite connue** : cookie de session gardé en mémoire seulement (pas persisté) — perdu au redémarrage de l'app ; le stockage sécurisé (`flutter_secure_storage`, voir ligne juste en dessous) reste à faire avant une vraie gestion de session 24h. `_rpc()` généralisé pour supporter aussi le `/web/dataset/call_kw` standard (voir F03 ci-dessous), pas seulement les 2 endpoints custom d'auth |
| F03 — Accueil : affichage produits (Flutter + backend) | **Terminé — validé en réel** | **Backend** : `security/ir.model.access.csv` + `security/ir_rule.xml` dans `echango_order` — le groupe portail n'avait par défaut AUCUN accès à `product.template`/`product.category` (vérifié contre le code source Odoo 19 des modules `product` et `sale`, aucune entrée portail trouvée), donc accès lecture seule accordé + `ir.rule` restreignant aux produits `sale_ok = true` (pas de fuite du catalogue interne). **Flutter** : `HomeScreen` réécrit — `OdooApiClient.searchRead()` (`search_read` standard via `call_kw`, pas de contrôleur custom) sur `product.template` (`name`, `list_price`, `image_128`), grille 2 colonnes, état vide et état d'erreur via `ErrorStateView` existant. **Écart assumé vs spec Expert Odoo** : filtre `sale_ok = true` à la place de `is_published` (champ qui n'existe pas sans le module `website_sale`, non installé) — pas de notion de "produits mis en avant" pour l'instant, tous les produits vendables s'affichent ; la curation viendra avec `x_vitrine_publique` (F00) si besoin. Piège rencontré en testant : `docker compose exec odoo odoo -u ...` contourne l'entrypoint de l'image officielle (qui traduit `HOST`/`USER`/`PASSWORD` en paramètres de connexion) — nécessite `--db_host=db --db_user=odoo --db_password=odoo` explicites pour cette commande ponctuelle (le `docker compose restart odoo` normal repasse bien par l'entrypoint, lui) |
| F04 — Catalogue & Recherche (Flutter + backend) | Terminé (code), non re-testé après correction | Aucun changement backend requis (mêmes droits portail que F03). **Flutter** : `CategoryProductsScreen` (grille filtrée `categ_id`, nom de catégorie transmis via `extra` de go_router depuis `CatalogScreen`), `SearchScreen` (`name ilike`, anti-rebond 400ms via `Timer`, pas de nouvelle dépendance). Nouveau widget partagé `lib/widgets/product_grid_tile.dart` (`ProductGridTile`) utilisé par Accueil/Catalogue/Recherche — évite de dupliquer 3 fois le décodage d'image + la mise en page ; badge "Épuisé" (`qty_available <= 0`) et bouton "+" optionnel (absent sur l'Accueil, présent en Catalogue/Recherche comme dans le wireframe) qui appelle `showComingSoon` (ajout réel au panier = F06, pas fait). Nouvelles clés `catalog.outOfStock` + `emptyStates.categories{Title,Message}` en FR/AR. **Bug signalé par l'utilisateur (capture d'écran) et corrigé** : `CatalogScreen` faisait un `search_read` direct sur `product.category`, ce qui remontait aussi les catégories techniques par défaut d'Odoo (Dépenses, Achats, Construction...) sans aucun produit vendable dedans. Remplacé par un `read_group` sur `product.template` (`groupby: categ_id`) — nouvelle méthode `OdooApiClient.readGroup()` — qui ne fait remonter que les catégories ayant réellement des produits visibles côté portail, avec le nombre de produits par catégorie en bonus. `security/ir.model.access.csv` gardé tel quel (accès `product.category` toujours nécessaire : Odoo doit lire ce modèle en interne pour résoudre le nom affiché du many2one `categ_id`, même sans `search_read` direct dessus depuis Flutter). **Non fait dans cette passe** : barre de recherche accessible depuis l'Accueil (QA F03, jamais implémentée, risque de complications de navigation cross-onglet avec `StatefulShellRoute` — à traiter séparément si besoin) |
| Firebase Cloud Messaging configuré | Non démarré | |
| Stockage sécurisé PIN (Keychain/Keystore) | Non démarré | Côté Flutter : `flutter_secure_storage` pressenti (pas encore ajouté) |
| Build & run réel sur simulateur/device (iOS/Android) | En cours | `flutter analyze` validé côté utilisateur (une passe) ; du nouveau code non re-vérifié ajouté depuis (validators, PinInputField, écrans auth câblés, états vides, `package_info_plus`) — à repasser en `flutter analyze`/`flutter run` avant de continuer. Non testable dans l'environnement Claude Code (pas de SDK Flutter/Android/Xcode) |

## 1. Fonctionnalités Phase 1 (F00–F17)

Colonne **Écrans** : placeholders créés + navigables (sans données ni logique métier réelle). Colonne **API Odoo** : intégration backend réelle.

| # | Fonctionnalité | Écrans | API Odoo | QA / critères d'acceptation | Notes |
|---|---|---|---|---|---|
| F00 | Vitrine publique | Terminé | ☐ | ☐ | Nécessite champ `x_vitrine_publique` |
| F01 | Onboarding | Terminé | — | ☐ | Aucun appel API |
| F02 | Authentification (inscription/connexion/invité) | Terminé | Terminé — inscription + connexion validées en réel via l'app | ☐ | Backend Odoo `/echango/auth/register` + `/login` + client Flutter, testés avec succès de bout en bout (app réelle sur émulateur). Reste : scénario de blocage PIN (5 échecs) pas testé en réel, session non persistée (voir §0), et QA complet (RTL, perf) pas encore passé en revue formelle. Mode invité géré localement (pas d'appel Odoo) |
| F03 | Accueil | Terminé | **Terminé — validé en réel** (grille produits affichée dans l'app après `-u echango_order`) | ☐ | Voir §0 pour le détail (accès portail accordé, filtre `sale_ok`, pas encore de "produits mis en avant"/bannière) |
| F04 | Catalogue & Recherche | Terminé | Terminé (code) — **corrigé après retour utilisateur**, non re-testé | ☐ | `CatalogScreen` (voir §0 pour le détail du bug corrigé), `CategoryProductsScreen` (grille filtrée `categ_id`), `SearchScreen` (`name ilike`, anti-rebond 400ms). Widget partagé `ProductGridTile` (Accueil + Catalogue + Recherche) avec badge "Épuisé" (`qty_available <= 0`) et bouton "+" (`showComingSoon` — ajout réel au panier = F06, pas encore fait). Restriction `sale_ok` déjà imposée côté serveur par l'`ir.rule` de F03, pas dupliquée côté client |
| F04 | Catalogue & Recherche | Terminé | ☐ | ☐ | |
| F05 | Fiche Produit | Terminé | ☐ | ☐ | |
| F06 | Panier | Terminé | ☐ | ☐ | |
| F07 | Checkout & Mode de Réception | Terminé | ☐ | ☐ | Zones de livraison (`x_delivery_zone`), créneaux |
| F08 | Confirmation & Suivi Commande | Terminé | ☐ | ☐ | Statuts synchronisés + notifs push |
| F09 | Historique Commandes & Reorder | Terminé | ☐ | ☐ | Reorder 1 tap |
| F10 | Profil Utilisateur | Terminé | ☐ | ☐ | Suppression compte : popup + saisie PIN (6-12 chiffres) implémentés (`delete_account_dialog.dart`) ; validation réelle du PIN + SMS de confirmation nécessitent Odoo |
| F11 | Notifications Push | Non démarré | ☐ | ☐ | Webhook Odoo → FCM. La permission notification (F14) est déjà demandée après confirmation de commande, mais aucun envoi réel |
| F12 | Partage Produit (Deep Link) | Terminé (partiel) | ☐ | ☐ | Bouton partage sur fiche produit (`share_plus`, sheet natif) avec lien placeholder. **Réception du deep link (Universal/App Links) non câblée** — nécessite un domaine réel + choix de techno (Branch.io vs Firebase Dynamic Links, cf. §4) + fichiers natifs `android/`/`ios/` |
| F13 | Pages Légales | Terminé (placeholder) | — | ☐ | Contenu réel à intégrer + validation juriste avant soumission stores |
| F14 | Permissions & États Système | Terminé | ☐ | ☐ | Écran maintenance + permissions réelles (`permission_handler`) : dialog d'explication puis demande système pour GPS (Register/CheckoutAddress/MyLocation) et notifications (auto après confirmation commande). **Déclarations natives Android/iOS pas encore ajoutées** (voir CLAUDE.md) |
| F15 | Code Promo | Terminé (placeholder dans récap checkout) | ☐ | ☐ | Module coupon Odoo 19 à valider |
| F16 | Annulation Commande | Terminé (popup confirmation) | ☐ | ☐ | Délai d'annulation à définir (PO) |
| F17 | Substitution Produit | Terminé | ☐ | ☐ | Écran substitution (produit original/suggestion, accepter/refuser). Accessible pour l'instant via un bouton démo dans le suivi de commande — en réel, déclenché par une notification push (dépend de F11) |

## 2. Sécurité (transversal — bloquant pour release)

| Exigence | Statut |
|---|---|
| HTTPS/TLS 1.3 sur tous les appels | Non démarré |
| PIN jamais stocké en clair (Keychain/Keystore) | Non démarré |
| Session 24h + re-auth PIN | Non démarré |
| Délai progressif tentatives PIN (1s/2s/4s/8s + blocage) | En cours — implémenté serveur (`res.users._check_pin`), non testé en réel |
| Filtrage strict des champs API (pas de surexposition) | Non démarré |
| Rate limiting endpoints publics (vitrine, deep links) | Non démarré |

## 3. i18n / RTL (transversal)

| Exigence | Statut |
|---|---|
| Externalisation complète des chaînes (fichiers de traduction FR/AR) | Terminé — vérifié automatiquement (`translations_completeness_test.dart`) |
| Layout RTL validé sur chaque écran | Non démarré |
| Formats date/heure localisés | Non démarré |

## 4. Points de vigilance ouverts (décisions à prendre — voir specs §6 / §7)

- [ ] Valider les statuts de commande Odoo avec l'Expert Odoo
- [ ] Définir le délai d'annulation commande autorisé
- [ ] Définir le délai de conservation des données après suppression de compte (RGPD)
- [ ] Définir les zones de livraison et codes postaux couverts
- [ ] Valider contenu CGU / politique de confidentialité avec un juriste
- [ ] Choisir la techno deep link (Branch.io vs Firebase Dynamic Links)
- [ ] Définir la page desktop de destination pour les deep links
- [ ] Confirmer la disponibilité des endpoints Odoo 19 listés dans les specs
- [ ] Valider le module coupon/promo compatible Odoo 19
- [ ] Valider la durée de blocage du compte après 5 échecs de PIN (15 min implémenté par défaut, arbitraire — voir §0 module F02)

## 5. Roadmap macro (rappel — voir `docs/specs_macro_drive_transport.md` §8)

- **Semaines 1-2** : développement app client (catalogue, panier, suivi statuts, bilingue FR/AR)
- **Semaine 3** : tests fonctionnels, validation RTL arabe, corrections
- **Semaine 4** : soumission App Store + Google Play

---

*Mettre à jour ce fichier à chaque avancée significative (changement de statut d'une fonctionnalité, décision prise sur un point de vigilance, etc.).*
