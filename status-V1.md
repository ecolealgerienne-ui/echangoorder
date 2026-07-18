# Status V1 — Echango Order (MVP Phase 1)

Suivi de l'avancement de l'implémentation. Statuts : `Non démarré` · `En cours` · `Bloqué` · `Terminé`.

Dernière mise à jour : 2026-07-18

**Stratégie en cours** : phase 1 = écrans + navigation complets, sans données ni backend (état local simulé uniquement pour piloter la navigation : session auth, langue). Phase 2 = branchement direct sur Odoo (pas de couche mock intermédiaire).

---

## 0. Setup projet

| Tâche | Statut | Notes |
|---|---|---|
| Repo Git créé (`main` + branche de travail) | Terminé | Repo initialisé, docs ajoutés |
| Specs macro & Phase 1 versées dans `docs/` | Terminé | `docs/specs_macro_drive_transport.md`, `docs/specs_phase1_echango_order.md` |
| `CLAUDE.md` rédigé | Terminé | |
| Scaffolding app React Native CLI (bare, TypeScript) | Terminé | `mobile/`, RN 0.86, package `com.echangoorder.app` |
| Navigation (stacks + bottom tabs) | Terminé | Tous les écrans F00-F17 créés en placeholders, navigables de bout en bout (`mobile/src/navigation/`) |
| Config i18n FR/AR + bascule RTL | Terminé (base) | i18next, fichiers `fr.json`/`ar.json`, bascule `I18nManager` + redémarrage app. Reste à valider visuellement le mirroring RTL sur device/simulateur |
| État local (session, langue) pour piloter la navigation | Terminé | `AuthContext`, `LanguageContext` — sera remplacé par la vraie session Odoo (F02) |
| Client API JSON-RPC Odoo | Non démarré | Branchement direct prévu après validation des écrans |
| Environnement Odoo 19 (dev/staging) accessible | Non démarré | Dépendance Expert Odoo |
| Firebase Cloud Messaging configuré | Non démarré | |
| Stockage sécurisé PIN (Keychain/Keystore) | Non démarré | |
| Build & run réel sur simulateur/device (iOS/Android) | Non démarré | Non testable dans l'environnement de dev actuel (pas de SDK Android/Xcode) — à faire sur poste local/CI |
| Nettoyage warnings/vuln `npm install` | Terminé (plancher atteint) | `npm audit` : 7 vulnérabilités modérées → 0 (bump `@react-native-community/cli*` en 20.2.0). ESLint migré en v9 (flat config, `eslint.config.js`) → warnings de dépréciation `eslint@8`/`@humanwhocodes/*`/`rimraf@3` éliminés. **Restent `glob@7.2.3`/`inflight@1.0.6` — non résolubles sans risque.** Chaîne exacte : `@react-native/jest-preset` → `babel-jest@29` → `babel-plugin-istanbul` → `test-exclude@6` → `glob@7`. `test-exclude` (utilisé par `jest --coverage`) appelle `require('glob')` comme fonction directe + `.sync()` — API supprimée dans `glob` v9+. Forcer un `glob` récent via `overrides` casserait silencieusement le rapport de couverture. Testé aussi le passage de `jest` en v30 : n'élimine pas le warning (preset RN 0.86 reste figé sur `babel-jest@^29.7.0`) et en ajoute un nouveau (`glob@10` déprécié côté Jest 30 lui-même) → reverté. Aucune vulnérabilité de sécurité (`npm audit` = 0) ; réparable uniquement par une future version du preset officiel `@react-native/jest-preset`. Option cosmétique pour masquer l'affichage : `npm install --loglevel=error`. |

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
| F10 | Profil Utilisateur | Terminé | ☐ | ☐ | Suppression compte (logique, PIN + SMS) — écran de confirmation PIN pas encore implémenté |
| F11 | Notifications Push | Non démarré | ☐ | ☐ | Webhook Odoo → FCM |
| F12 | Partage Produit (Deep Link) | Non démarré | ☐ | ☐ | Branch.io / Firebase Dynamic Links à choisir |
| F13 | Pages Légales | Terminé (placeholder) | — | ☐ | Contenu réel à intégrer + validation juriste avant soumission stores |
| F14 | Permissions & États Système | Terminé (partiel) | ☐ | ☐ | Écran maintenance créé ; demandes de permission natives (GPS/notifs) pas encore implémentées |
| F15 | Code Promo | Terminé (placeholder dans récap checkout) | ☐ | ☐ | Module coupon Odoo 19 à valider |
| F16 | Annulation Commande | Terminé (popup confirmation) | ☐ | ☐ | Délai d'annulation à définir (PO) |
| F17 | Substitution Produit | Non démarré | ☐ | ☐ | Délai de réponse client 30 min |

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
