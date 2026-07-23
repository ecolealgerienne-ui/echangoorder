# Status V1 — Echango Order (MVP Phase 1)

Suivi de l'avancement. Statuts : `Non démarré` · `En cours` · `Bloqué` · `Terminé`. Pour les décisions produit et leur justification, voir `CLAUDE.md` (ce fichier ne garde que l'état courant, pas l'historique du raisonnement).

Dernière mise à jour : 2026-07-23

**État actuel** : Phase 1 (F00-F17) fonctionnellement close et validée en réel par l'utilisateur. Chantier design "Casbah" + simplification de navigation livrés et validés (§3). Phase 1.5 (F11/F12) en attente du déploiement VPS (§2). Nouveau chantier Phase 2 en cours : préparation groupée des commandes, backend livré, débogage en cours en test réel (§4).

**🐛 Bug signalé par l'utilisateur et corrigé (2026-07-23)** : `CartBar` continuait d'afficher le total d'une commande qui vient d'être confirmée, en naviguant sur "Mes commandes". Pas un résidu — le devis passe en `state='sent'` à la confirmation mais reste volontairement "le panier courant" côté serveur (`cart_controller.py._cart_order()`, domaine `draft`/`sent`, voir CLAUDE.md § Statuts de commande) pour permettre d'y ajouter des articles tant qu'un opérateur ne l'a pas pris en charge. Décision produit (2026-07-23, après clarification) : l'app doit quand même l'afficher comme panier vide immédiatement après confirmation, sans changer ce comportement serveur. `CartState.clearLocally()` (nouveau, réinitialise l'état en mémoire sans appel serveur) appelé à la place de `refresh()` juste après une confirmation réussie (`checkout_summary_screen.dart`) — un ajout ultérieur resynchronise l'état correct via `add()`. **Non testé en réel.**

## 1. Fonctionnalités Phase 1 (F00–F17)

| # | Fonctionnalité | État | Notes |
|---|---|---|---|
| F00 | Vitrine publique | Terminé, validé | Endpoint public dédié (`auth='public'`), `x_vitrine_publique` |
| F01 | Onboarding | Terminé, validé | `PageView` 3 slides, indicateur animé |
| F02 | Authentification | Terminé, validé | PIN 6-12 chiffres, blocage progressif (15 min au 5e échec, arbitraire — à valider) ; "PIN oublié" → modérateur (`x_pin_reset_wizard`) |
| F03 | Accueil | Terminé, validé | Filtre `sale_ok` (pas `is_published`, `website_sale` non installé) |
| F04 | Catalogue & Recherche | Fusionné dans F03 | Recherche texte supprimée (catalogue ≤300 produits, bandeau catégories suffit) |
| F05 | Fiche Produit | Terminé, validé | `qty_available` bloque "Ajouter au panier" si épuisé |
| F06 | Panier | Terminé, validé | = devis Odoo brouillon (`sale.order` draft). Pas de panier invité (partner temporaire non implémenté) |
| F07 | Checkout & Mode de Réception | Terminé, validé | GPS ne remplit pas l'adresse (service de géocodage non choisi) ; capacité créneaux (`x_timeslot_capacity`) |
| F08 | Confirmation & Suivi Commande | Terminé, validé | Statut simplifié pending/in_progress/completed (`stock.picking`) ; suivi temps réel hors scope (→F11) |
| F09 | Historique & Reorder | Terminé, validé | |
| F10 | Profil Utilisateur | Terminé, validé | Adresses (CRUD + favorite + GPS), suppression de compte réelle. SMS de confirmation hors scope (pas de fournisseur choisi) |
| F11 | Notifications Push | Reporté — Phase 1.5 | Code-complet, attend VPS + FCM prod |
| F12 | Partage Produit / Deep Link | Partiel | Bouton partage OK ; réception du deep link reportée Phase 1.5 |
| F13 | Pages Légales | Terminé | Texte provisoire — validation juridique requise avant soumission stores |
| F14 | Permissions & États Système | Terminé (code) | Déclarations natives Android/iOS pas encore ajoutées (voir CLAUDE.md § Environnement mobile) |
| F15 | Code Promo | Terminé, validé | `sale_loyalty` standard — programme "Discount Code" à créer manuellement en back-office avant de tester |
| F16 | Annulation Commande | Terminé, validé | Annulable jusqu'à "Prête" (`prep_status`), voir CLAUDE.md § Statuts de commande |
| F17 | Substitution Produit | Terminé, validé | Le client choisit toujours le substitut, voir CLAUDE.md § Produits de substitution |

## 2. Phase 1.5

| # | Fonctionnalité | Bloqué par |
|---|---|---|
| F11 | Notifications Push | Déploiement VPS (webhook Odoo → FCM) |
| F12 | Réception deep link | Déploiement VPS (domaine + fichiers d'association) + publication stores |

## 3. Chantier design "Casbah" + navigation (Phase 2, clos)

Palette/typographie/dark mode complets, audit RTL/accessibilité, checkout en feuille modale, timeline de suivi de commande — voir `docs/design_direction.md`. Navigation simplifiée : F04 fusionné dans l'Accueil, recherche texte supprimée, barre d'onglets retirée (2 destinations : Accueil/Profil), panier en feuille flottante (`CartBar`). **Livré et validé en réel par l'utilisateur** (2026-07-20/21) — détail des correctifs dans le log git.

## 4. Préparation groupée des commandes (Phase 2, en cours)

Voir `CLAUDE.md` § Préparation groupée et `docs/specs_preparation_groupee.md` pour la conception complète.

**Code terminé, plusieurs bugs trouvés et corrigés en test réel** (WSL/Docker utilisateur — ce sandbox n'a pas Docker) :
- Moteur de clustering (`batch_picking_engine.py`, pur Python) : testé et validé directement en sandbox (5 scénarios).
- Dépendance `stock_picking_batch` manquante (`AttributeError` sur `batch_id`) — corrigé.
- `NotNullViolation` sur `order_id` à la sauvegarde du wizard — `force_save="1"` insuffisant ; corrigé en transformant `order_id`/`line_count`/`qty_total` en champs **calculés** (dépendants de `picking_id` uniquement) plutôt que peuplés par défaut.
- `stock.quant.package` renommé `stock.package` en Odoo 19 (`KeyError` au clic sur "Créer les lots") — corrigé.
- "Recalculer les suggestions" écrasait les numéros de lot déjà ajustés à la main — corrigé (n'ajoute plus que les commandes pas encore listées).
- Paramètres réglables : `res.config.settings` abandonné (Odoo l'ouvre dans la coquille complète de l'app Réglages, impossible de revenir en arrière) — remplacé par un assistant dédié (`x_batch_picking_settings_wizard`).
- Aucun mécanisme standard ne relie le lot Pick à ses transferts Pack (ni Batch ni Wave Transfers). Décision produit (2026-07-22) : pas de code pour ça — un 2e lot automatique et le module OCA `stock_picking_show_linked` ont été envisagés puis écartés (complexité/dépendance externe pas prioritaires). L'opérateur de tri retrouve le transfert Pack via une recherche standard (Inventaire > Transferts, filtre "Document d'origine").
- **Conception de l'app préparateur (2026-07-22)** — `docs/specs_app_preparateur.md` : architecture complète (JSON-RPC, auth par compte/terminal, scénarios Collecte/Tri/Expédition, scan strict avec abstraction douchette/caméra, file de scan optimiste hors connexion) passée par 3 revues spécialisées (Odoo, mobile/Flutter, logistique) et validée. Précédent étudié (OCA Shopfloor/Camptocamp Moove, arrêté à Odoo 18, sert de référence de conception uniquement). Décisions produit encore ouvertes : modèle physique de collecte (chariot compartimenté vs vrac + tri différé — change le sens du double scan), choix du terminal, confirmation d'un projet Flutter séparé. **Développement non planifié dans l'immédiat.**
- **Bug trouvé en concevant l'app préparateur, pas encore corrigé** : `batch_picking_wizard.py._candidate_orders()` prend le premier picking Pick (`[:1]`) — casse en cas de reliquat (backorder) créant un 2e picking Pick pour la même commande. À corriger avant un usage intensif du wizard existant.

**Reste à faire** : valider le parcours Pick → Pack (zone de tri, avec le 2e lot) → Ship en conditions réelles (processus détaillé donné à l'utilisateur, pas encore testé de bout en bout avec ce dernier correctif) ; calibrer les paramètres par défaut avec des données réelles.

## 5. Sécurité (transversal — bloquant pour release)

| Exigence | État | Notes |
|---|---|---|
| HTTPS/TLS 1.3 | Non démarré | Prod uniquement (VPS) |
| PIN jamais en clair | Terminé | Hash uniquement côté Odoo (`x_pin`), rien côté app |
| Session 24h + re-auth PIN | Terminé (code), non testé en réel | `x_last_activity` (`res.users`) + `require_fresh_session` sur tous les endpoints `/echango/*` (y compris historique/suivi de commande, migrés depuis `search_read` direct pour rester couverts). Écriture throttlée à 2 min (`ACTIVITY_WRITE_THROTTLE`) suite à un conflit d'écriture concurrente trouvé en test réel. `ReauthPinScreen` + `fullLogout()` (cookie + état local) |
| Délai progressif PIN (1/2/4/8s + blocage) | Terminé (code), non testé | `res.users._check_pin`, verrou `SELECT ... FOR UPDATE` (anti race condition sur tentatives parallèles) |
| Filtrage champs API | Audité | `standard_price` restreint (`groups=`) sur `product.template`/`product.product` — reste du catalogue filtré au niveau des lignes (`ir.rule`) |
| Rate limiting endpoints publics | Terminé | `x_rate_limit` (fenêtre fixe par IP, verrou anti race condition + contrainte unique), limite additionnelle par numéro sur `auth.login` |

## 6. i18n / RTL (transversal)

| Exigence | État |
|---|---|
| Externalisation complète | Terminé — vérifié par `translations_completeness_test.dart` |
| RTL par écran | En cours — audit statique fait (icônes directionnelles gérées manuellement où nécessaire), validation visuelle réelle écran par écran restante |
| Formats date/heure localisés | Non démarré |

## 7. Points ouverts (décisions à prendre)

- [ ] Valider les statuts de commande avec l'Expert Odoo.
- [ ] Durée de conservation des données après suppression de compte (RGPD).
- [ ] Zones de livraison réelles + codes postaux couverts (`x_delivery_zone` à peupler en back-office).
- [ ] Validation juridique CGU/confidentialité avant soumission aux stores.
- [ ] Techno deep link (Branch.io vs Firebase Dynamic Links) + page desktop de destination.
- [ ] Durée de blocage compte après 5 échecs PIN (15 min, arbitraire).
- [ ] Panier invité (partner temporaire Odoo, non implémenté — specs §"Mode invité").
- [ ] Service de géocodage inverse pour le bouton GPS (F07).
- [ ] Fournisseur SMS (confirmation après suppression de compte).
- [ ] Images produit → S3 au déploiement VPS (voir CLAUDE.md § Images produit).
- [ ] Préparation groupée : seuil de fenêtre de temps compatible, définition de la charge opérateur, calibration des 5 paramètres par défaut, gestion des ruptures de stock en cours de tournée (voir `docs/specs_preparation_groupee.md`).

## 8. Setup / environnement

- Repo Git, `CLAUDE.md`, scaffolding Flutter (`mobile/`) — `android`/`ios` générés côté utilisateur (voir CLAUDE.md § Environnement mobile).
- Navigation (`go_router`), i18n (`easy_localization`), état local (`auth_state.dart`, persisté via `shared_preferences`).
- Infra obligatoire pour tout nouveau code : gestion d'erreurs (`errors/`), validation (`validation/validators.dart`) — voir CLAUDE.md.
- Backend Odoo 19 + Postgres (Docker/WSL) — exécuté et validé côté utilisateur, voir CLAUDE.md § Environnement backend.

## 9. Roadmap macro (rappel — voir `docs/specs_macro_drive_transport.md` §8)

- **Semaines 1-2** : développement app client (catalogue, panier, suivi statuts, bilingue FR/AR).
- **Semaine 3** : tests fonctionnels, validation RTL arabe, corrections.
- **Semaine 4** : soumission App Store + Google Play.
