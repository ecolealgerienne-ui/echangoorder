# Status V1 — Echango Order (MVP Phase 1)

Suivi de l'avancement de l'implémentation. Statuts : `Non démarré` · `En cours` · `Bloqué` · `Terminé`.

Dernière mise à jour : 2026-07-18

**Stratégie en cours** : phase 1 = écrans + navigation complets, sans données ni backend (état local simulé uniquement pour piloter la navigation : session auth). Phase 2 = branchement direct sur Odoo (pas de couche mock intermédiaire).

**⚠️ Changement de stack (2026-07-18)** : le projet a démarré en React Native puis a été **entièrement basculé sur Flutter** en cours de route (choix de l'équipe, expérience Flutter préalable). Tout le code React Native a été supprimé et réécrit en Flutter/Dart — même périmètre fonctionnel (F00-F17), mêmes clés i18n, même logique de navigation, portés dans un nouveau framework. Voir CLAUDE.md § Stack technique pour la note de décision.

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
| F10 — Suppression de compte (popup + PIN) | Terminé (UI) | `delete_account_dialog.dart` — saisie 4 chiffres, aucune validation réelle (attend Odoo) |
| **Nouvelles dépendances non vérifiées ici** | À vérifier en local | `permission_handler`, `share_plus`, `shared_preferences` ajoutés à `pubspec.yaml` — Claude Code n'a pas pu relancer `flutter pub get`/`flutter analyze` après ces ajouts (même limitation réseau que d'habitude). À relancer avant de continuer. API `share_plus` notamment : le package a changé d'API récemment (`SharePlus.instance.share(ShareParams(...))`), à confirmer que la version résolue localement la supporte |
| Client API JSON-RPC Odoo | Non démarré | Branchement direct prévu après validation des écrans |
| Environnement Odoo 19 (dev/staging) accessible | Non démarré | Dépendance Expert Odoo |
| Firebase Cloud Messaging configuré | Non démarré | |
| Stockage sécurisé PIN (Keychain/Keystore) | Non démarré | Côté Flutter : `flutter_secure_storage` pressenti (pas encore ajouté) |
| Build & run réel sur simulateur/device (iOS/Android) | En cours | `flutter analyze` validé côté utilisateur ; `flutter run` en cours de mise en place (génération `android`/`ios`). Non testable dans l'environnement Claude Code (pas de SDK Flutter/Android/Xcode) |

## 1. Fonctionnalités Phase 1 (F00–F17)

Colonne **Écrans** : placeholders créés + navigables (sans données ni logique métier réelle). Colonne **API Odoo** : intégration backend réelle.

| # | Fonctionnalité | Écrans | API Odoo | QA / critères d'acceptation | Notes |
|---|---|---|---|---|---|
| F00 | Vitrine publique | Terminé | ☐ | ☐ | Nécessite champ `x_vitrine_publique` |
| F01 | Onboarding | Terminé | — | ☐ | Aucun appel API |
| F02 | Authentification (inscription/connexion/invité) | Terminé | ☐ | ☐ | Endpoint custom téléphone+PIN à développer côté Odoo |
| F03 | Accueil | Terminé | ☐ | ☐ | |
| F04 | Catalogue & Recherche | Terminé | ☐ | ☐ | |
| F05 | Fiche Produit | Terminé | ☐ | ☐ | |
| F06 | Panier | Terminé | ☐ | ☐ | |
| F07 | Checkout & Mode de Réception | Terminé | ☐ | ☐ | Zones de livraison (`x_delivery_zone`), créneaux |
| F08 | Confirmation & Suivi Commande | Terminé | ☐ | ☐ | Statuts synchronisés + notifs push |
| F09 | Historique Commandes & Reorder | Terminé | ☐ | ☐ | Reorder 1 tap |
| F10 | Profil Utilisateur | Terminé | ☐ | ☐ | Suppression compte : popup + saisie PIN (4 chiffres) implémentés (`delete_account_dialog.dart`) ; validation réelle du PIN + SMS de confirmation nécessitent Odoo |
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
| Délai progressif tentatives PIN (1s/2s/4s/8s + blocage) | Non démarré |
| Filtrage strict des champs API (pas de surexposition) | Non démarré |
| Rate limiting endpoints publics (vitrine, deep links) | Non démarré |

## 3. i18n / RTL (transversal)

| Exigence | Statut |
|---|---|
| Externalisation complète des chaînes (fichiers de traduction FR/AR) | Non démarré |
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

## 5. Roadmap macro (rappel — voir `docs/specs_macro_drive_transport.md` §8)

- **Semaines 1-2** : développement app client (catalogue, panier, suivi statuts, bilingue FR/AR)
- **Semaine 3** : tests fonctionnels, validation RTL arabe, corrections
- **Semaine 4** : soumission App Store + Google Play

---

*Mettre à jour ce fichier à chaque avancée significative (changement de statut d'une fonctionnalité, décision prise sur un point de vigilance, etc.).*
