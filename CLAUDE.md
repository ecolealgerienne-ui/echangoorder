# CLAUDE.md

## ⚠️ Règle impérative — synchronisation avant toute nouvelle branche

**Avant de créer une nouvelle branche, il faut impérativement synchroniser avec toutes les branches distantes** (`git fetch --all`) afin de ne rien perdre et de récupérer tous les commits existants dans la nouvelle branche (partir de l'état le plus à jour, typiquement `origin/main`, plutôt que d'un historique local potentiellement obsolète). Ne jamais créer une branche à partir d'un état local non synchronisé.

Ce fichier guide Claude Code (et tout contributeur) sur le contexte, les conventions et l'état du projet **Echango Order**.

## Contexte projet

Echango Order est une app mobile de commande alimentaire (livraison à domicile ou retrait en magasin), premier client "dogfooding" de la plateforme B2B **Echango Delivery** (Fleetbase). Les deux produits sont décrits dans `docs/specs_macro_drive_transport.md`.

La **Phase 1 (MVP)** ne concerne que l'app mobile client. Elle est spécifiée en détail dans `docs/specs_phase1_echango_order.md` (specs v1.5 — 18 fonctionnalités F00 à F17, validées par Product Owner / UX Designer / Expert Odoo / QA Engineer).

**Toujours consulter ces deux documents avant de développer une fonctionnalité.** Ils font foi pour : wireframes, endpoints Odoo attendus, champs custom, et critères d'acceptation QA.

## Stack technique (Phase 1)

- **Frontend mobile** : React Native (iOS & Android), bilingue FR/AR avec support RTL natif
- **Backend** : Odoo 19, API JSON-RPC (`/web/dataset/call_kw`)
- **Notifications** : Firebase Cloud Messaging
- **Paiement** : cash uniquement (à la réception / au retrait) — aucune intégration paiement en ligne en Phase 1
- **Auth** : téléphone + PIN 4 chiffres (endpoint custom Odoo, PIN hashé, stockage device via iOS Keychain / Android Keystore)

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
