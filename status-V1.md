# Status V1 — Echango Order (MVP Phase 1)

Suivi de l'avancement de l'implémentation. Statuts : `Non démarré` · `En cours` · `Bloqué` · `Terminé`.

Dernière mise à jour : 2026-07-18

---

## 0. Setup projet

| Tâche | Statut | Notes |
|---|---|---|
| Repo Git créé (`main` + branche de travail) | Terminé | Repo initialisé, docs ajoutés |
| Specs macro & Phase 1 versées dans `docs/` | Terminé | `docs/specs_macro_drive_transport.md`, `docs/specs_phase1_echango_order.md` |
| `CLAUDE.md` rédigé | Terminé | |
| Scaffolding app React Native (iOS & Android) | Non démarré | |
| Config i18n FR/AR + RTL | Non démarré | |
| Config navigation (stack + tab bar) | Non démarré | |
| Client API JSON-RPC Odoo | Non démarré | |
| Environnement Odoo 19 (dev/staging) accessible | Non démarré | Dépendance Expert Odoo |
| Firebase Cloud Messaging configuré | Non démarré | |
| Stockage sécurisé PIN (Keychain/Keystore) | Non démarré | |

## 1. Fonctionnalités Phase 1 (F00–F17)

| # | Fonctionnalité | Statut | Frontend RN | API Odoo | QA / critères d'acceptation | Notes |
|---|---|---|---|---|---|---|
| F00 | Vitrine publique | Non démarré | ☐ | ☐ | ☐ | Nécessite champ `x_vitrine_publique` |
| F01 | Onboarding | Non démarré | ☐ | — | ☐ | Aucun appel API |
| F02 | Authentification (inscription/connexion/invité) | Non démarré | ☐ | ☐ | ☐ | Endpoint custom téléphone+PIN à développer côté Odoo |
| F03 | Accueil | Non démarré | ☐ | ☐ | ☐ | |
| F04 | Catalogue & Recherche | Non démarré | ☐ | ☐ | ☐ | |
| F05 | Fiche Produit | Non démarré | ☐ | ☐ | ☐ | |
| F06 | Panier | Non démarré | ☐ | ☐ | ☐ | |
| F07 | Checkout & Mode de Réception | Non démarré | ☐ | ☐ | ☐ | Zones de livraison (`x_delivery_zone`), créneaux |
| F08 | Confirmation & Suivi Commande | Non démarré | ☐ | ☐ | ☐ | Statuts synchronisés + notifs push |
| F09 | Historique Commandes & Reorder | Non démarré | ☐ | ☐ | ☐ | Reorder 1 tap |
| F10 | Profil Utilisateur | Non démarré | ☐ | ☐ | ☐ | Suppression compte (logique, PIN + SMS) |
| F11 | Notifications Push | Non démarré | ☐ | ☐ | ☐ | Webhook Odoo → FCM |
| F12 | Partage Produit (Deep Link) | Non démarré | ☐ | ☐ | ☐ | Branch.io / Firebase Dynamic Links à choisir |
| F13 | Pages Légales | Non démarré | ☐ | — | ☐ | Contenu à valider avec juriste avant soumission stores |
| F14 | Permissions & États Système | Non démarré | ☐ | ☐ | ☐ | Écran maintenance, permissions GPS/notifs |
| F15 | Code Promo | Non démarré | ☐ | ☐ | ☐ | Module coupon Odoo 19 à valider |
| F16 | Annulation Commande | Non démarré | ☐ | ☐ | ☐ | Délai d'annulation à définir (PO) |
| F17 | Substitution Produit | Non démarré | ☐ | ☐ | ☐ | Délai de réponse client 30 min |

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
