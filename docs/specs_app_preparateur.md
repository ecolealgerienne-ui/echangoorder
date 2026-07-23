# App Préparateur — architecture backend Odoo + scan code-barres

Document de conception pour la future app mobile préparateur (roadmap
macro, hors périmètre Phase 1/1.5 — **pas de développement prévu dans
l'immédiat**, cette spec fige la conception pour ne pas redécouvrir les
contraintes le jour où ce chantier démarre). Complète
`docs/specs_preparation_groupee.md` §6 sans le dupliquer.

Conception passée par 3 revues spécialisées avant validation (agents
dédiés : Odoo/backend, mobile/Flutter, logistique/entrepôt) — le détail de
ce qu'elles ont trouvé et les décisions qui en découlent sont repris
directement dans ce document plutôt qu'archivés à part.

## 1. Contexte et objectif

Suite au chantier "préparation groupée des commandes" (batch picking +
zone de tri, voir CLAUDE.md § Préparation groupée), deux limites ont été
identifiées à l'usage réel du back-office Odoo standard :

1. Aucun lien de navigation direct entre le lot de collecte (Pick) et les
   transferts de tri (Pack) des mêmes commandes — résolu pour l'usage
   back-office actuel par une simple recherche manuelle (décision produit
   2026-07-22), mais reste un frein pour un usage intensif.
2. Absence de scan code-barres en Odoo 19 Community (ni l'app Barcode
   native — Enterprise uniquement, ni son équivalent OCA — arrêté à la
   version 16.0, voir §2). Besoin confirmé : éliminer les erreurs de
   frappe à la collecte ET à la mise en bac.

Objectif : concevoir l'architecture de la future app préparateur qui
résout ces deux limites nativement, en s'appuyant au maximum sur les
fonctionnalités standards d'Odoo (**directive explicite de l'utilisateur,
2026-07-22** : "utiliser à max les fonctionnalités d'Odoo pour rester dans
les standards de la logistique") — même principe "standard avant custom"
déjà appliqué à tout le reste du projet (CLAUDE.md), étendu ici.

## 2. Précédents étudiés

**OCA `stock-logistics-shopfloor`** (historiquement `OCA/wms`) — vérifié
directement contre le code source et le README (pas supposé) :

- Origine : développé par Camptocamp (suite commerciale "Moove"),
  open-sourcé à l'OCA — Shopfloor est la partie scan de Moove, pas un
  produit concurrent.
- Architecture confirmée : module backend `shopfloor` exposant une API
  REST/JSON, authentification par clé API (header `API-KEY`), consommé
  par un frontend mobile séparé (`shopfloor_mobile`) — même schéma "API
  backend + app mobile dédiée" retenu ici.
- 6 scénarios documentés : Cluster Picking, Zone Picking,
  Checkout/Packing, Delivery, Location Content Transfer, Single Pack
  Transfer. Mapping retenu pour ce projet : Cluster Picking → notre
  Collecte, Checkout/Packing → notre Tri, Delivery → notre Expédition.
  Zone Picking écarté (un seul entrepôt, pas de zonage formalisé), les 2
  derniers écartés (mouvements internes hors périmètre).
- **Limite pratique** : dépôt porté seulement jusqu'à Odoo 18.0 — pas
  installable avec notre Odoo 19. Sert de référence de conception
  (découpage en scénarios, forme de l'API), pas de dépendance à installer.

**Camptocamp "Odoo Moove"** : le produit commercial d'origine — même
lignage que Shopfloor, pas une architecture alternative.

## 3. Principe directeur — standard avant custom

Le modèle de données de l'app repose exclusivement sur des modèles Odoo
déjà standards et déjà en place : `stock.picking`, `stock.picking.batch`,
`stock.move.line`, `stock.package`, `sale.order`. Confirmé par la revue
Odoo : `stock.move.line.picked`/`quantity` (Pick), `result_package_id`
(Pack), `stock.picking.batch.user_id` (affectation opérateur) couvrent
déjà les besoins de suivi — **aucun nouveau modèle "session de scan" ou
"suivi de collecte" custom** n'est nécessaire pour cette v1.

Le moteur de clustering (`batch_picking_engine.py`) reste la seule vraie
partie custom (aucun équivalent standard, déjà justifié) — voir §4 pour
la décision sur son exposition (ou non) à l'app.

## 4. Architecture retenue

### 4.1 API — JSON-RPC custom, pas REST

Confirmé par la revue Odoo : cohérent avec l'existant (`/echango/*`,
`type="jsonrpc"`, `auth="user"`), pas de bénéfice réel du REST ici (aucun
consommateur tiers prévu contrairement à Shopfloor, pensé pour
l'interopérabilité multi-clients ; aucun contenu vraiment cacheable, ce
sont des mutations d'état de stock). Organisé par scénario (un groupe
d'endpoints par étape), comme Shopfloor, pas un contrôleur fourre-tout.

### 4.2 Authentification — session standard, compte par terminal

**Décision retenue** (revue Odoo) : réutiliser le mécanisme de session
standard déjà en place (`auth="user"` + `require_fresh_session`), avec un
**compte interne par terminal** (pas par opérateur humain) plutôt qu'un
login individuel à chaque prise de poste — compromis simplicité/
traçabilité éprouvé en entrepôt. Si un jour un mécanisme par clé API est
préféré (terminal partagé sans session persistante), Odoo a un mécanisme
**standard** pour ça (`res.users.apikeys`, natif depuis la v14) — pas
besoin de réinventer le schéma de clé API à la Shopfloor.

### 4.3 Scénario "Collecte" (Pick) — quantité agrégée, pas encore allouée

Lit un `stock.picking.batch` assigné à l'opérateur, ses `stock.move.line`
(produit, quantité demandée, emplacement). **Le scan à cette étape
confirme une quantité AGRÉGÉE** (total du produit pour tout le lot, pas
encore réparti par commande) — précision ajoutée suite à la revue
logistique : le texte initial ("décrémenter la quantité collectée") était
ambigu, risquant de faire scanner une allocation par commande dès le
Pick, ce qui rendrait le scan du Pack redondant. Valide le batch une fois
terminé (`action_done()` standard).

**Le moteur de clustering n'est PAS exposé à l'app dans cette v1**
(décision retenue suite à la revue Odoo, qui a identifié un risque de
concurrence réel : deux déclenchements simultanés — wizard back-office et
appel app — pourraient créer deux lots concurrents sur les mêmes
commandes avant que l'écriture de `batch_id` du premier ne soit visible,
faute de verrou explicite dans `action_create_batches()`). Séparation des
rôles retenue : un responsable planifie les lots depuis le back-office
Odoo (wizard déjà existant), les opérateurs exécutent depuis l'app.

### 4.4 Scénario "Tri" (Pack) — allocation par commande

Lit les `stock.picking` de type Pack pour les commandes du lot venant
d'être collecté — **résout nativement** le problème de navigation Pick→
Pack rencontré en back-office : contrairement à l'opérateur back-office
qui doit chercher manuellement (recherche par "Document d'origine»),
l'app sait déjà quel lot vient d'être traité et enchaîne directement.

**Le scan à cette étape fait l'allocation par commande** (ce produit va
dans ce bac précis, `result_package_id`) — complète le scan agrégé du
Pick, pas redondant avec lui si les deux rôles sont bien distincts (voir
§4.3).

**Correctif de conception suite à la revue Odoo** : la résolution des
pickings Pack d'une commande doit agréger **tous** les pickings Pack
actifs de cette commande, pas prendre le premier trouvé
(`filtered(...)[:1]`, pattern actuellement utilisé dans
`batch_picking_wizard.py._candidate_orders()` pour le Pick). Un
**reliquat (backorder)** sur le Pick — rupture partielle découverte en
cours de collecte, déjà un scénario réel rencontré en test — crée un 2e
picking Pick pour la même commande, et par ricochet potentiellement 2
pickings Pack distincts pour cette même commande. Le pattern `[:1]` casse
dans ce cas ; l'app doit lister tous les Pack actifs par commande, pas en
supposer un seul.

### 4.5 Scénario "Expédition" (Ship) — inchangé

A priori inchangé par rapport à F08 existant (déjà couvert par
`order_controller.py._prep_status()`) — pas de nouveau scénario
nécessaire ici, sauf besoin d'un scan à la remise au client/chauffeur (non
tranché, pas bloquant pour cette v1).

### 4.6 Scan — vérification stricte, abstraction du terminal

**Décision retenue** (convergence des revues mobile et logistique) : le
scan fait une **vérification stricte** (le code scanné doit correspondre
exactement à la ligne attendue), pas une simple confirmation de présence
— une confirmation molle ne protège de rien de plus qu'un clic "fait" et
ne sert pas l'objectif annoncé ("éliminer les erreurs de frappe"). Sur
mismatch : feedback immédiat (son + vibration, indispensable en
environnement bruyant/entrepôt), re-scan immédiat possible, et un
**override manuel explicite et journalisé** (bouton dédié, pas un simple
"ignorer") pour les vraies substitutions — **routé vers le mécanisme F17
déjà existant** (`x_substitute_product_ids`), pas une nouvelle mécanique.

**Architecture d'entrée de scan abstraite dès le départ** (recommandation
convergente mobile + logistique) : une interface (`ScanInputService` ou
équivalent) avec au moins deux implémentations possibles — douchette
Bluetooth/USB (event clavier, "keyboard wedge") et caméra
(`mobile_scanner` ou équivalent) — pour ne pas coupler l'app à un matériel
précis. Piège identifié par la revue mobile à anticiper dans
l'implémentation : un dialog qui vole le focus clavier après un scan
manqué rend une douchette silencieusement inopérante (l'opérateur croit
avoir scanné, la ligne n'est jamais validée) — nécessite un `FocusNode`
dédié systématiquement re-focalisé, et un buffer avec timeout (pas un
simple `onSubmitted` sur retour chariot, certaines douchettes n'envoient
pas de terminateur configuré par défaut).

### 4.7 Mode dégradé (pas hors-ligne complet)

**Décision retenue** (revue mobile) : contrairement à l'app cliente (pas
de mode hors-ligne, acceptable pour un usage grand public en conditions de
connectivité normales), un entrepôt a des zones mortes structurelles
(racks métalliques, chambre froide) — un scan qui échoue silencieusement
pendant une collecte en lot peut bloquer plusieurs commandes à la fois.
Pas d'architecture offline-first complète pour cette v1 (trop lourd), mais
une **file locale optimiste** : chaque scan est acquitté visuellement
côté app immédiatement, mis en file, synchronisé en arrière-plan, avec un
indicateur "en attente de synchronisation" visible — seule la validation
finale du lot (étape qui écrit réellement l'état Odoo) exige une
connexion active et bloque explicitement si la file n'est pas vide.

### 4.8 Gestion des exceptions de scan (v1 minimale, pas de nouveau modèle)

- Code-barres illisible/absent → saisie manuelle en secours,
  **restreinte à la liste attendue du picking** (pas une recherche
  catalogue libre, source d'erreur), journalisée comme "scan manuel" pour
  ne pas perdre la traçabilité.
- Code-barres scanné mais inconnu du système → signal de qualité de
  données (code-barres non enregistré sur `product.template`) : même
  repli (sélection manuelle restreinte + journalisation de l'anomalie pour
  correction en masse ultérieure).
- Rupture découverte pendant le scan → réutiliser strictement le flux F17
  déjà conçu (ligne indisponible + substituts pré-définis), pas de
  nouvelle mécanique.

## 5. Points ouverts — décisions produit/métier à trancher avec l'utilisateur

Ces points ne peuvent pas être tranchés par la conception seule — ce sont
des choix d'équipement ou de portée qui appartiennent à l'exploitant :

- **Modèle physique de collecte** (trouvaille de la revue logistique, pas
  un détail) : chariot à compartiments dès le Pick (un bac par commande
  déjà rempli en marchant, le Pack ne fait alors qu'un contrôle) vs
  collecte en vrac avec tri complet reporté au Pack (double manutention de
  chaque article, plus lent, plus de risque de mélange). C'est un choix
  d'équipement/investissement, pas une décision technique — **détermine
  le sens même du double scan** (§4.3/§4.4), à trancher avant de détailler
  davantage les scénarios Pick/Pack.
- **Terminal** : douchette Bluetooth/USB dédiée (recommandée par les 2
  revues terrain pour un usage réel — gants, froid, cadence répétitive,
  robustesse) vs téléphone personnel de l'opérateur (caméra, acceptable
  en v1 très faible volume). L'architecture (§4.6) reste agnostique du
  choix, mais le matériel réel disponible/budgété doit être connu avant
  l'implémentation.
- **Nouveau projet Flutter séparé** (recommandé par la revue mobile :
  public différent, permissions disjointes — scan seul vs GPS/
  notifications côté client —, UI différente, cycle de déploiement
  séparé, budget taille d'app à ne pas polluer) — à confirmer avec
  l'utilisateur avant de l'acter, c'est un choix de portée structurant.
- **Niveau de tolérance de la file de scan optimiste** (§4.7) : durée
  maximale avant blocage si la synchronisation ne se fait pas, à affiner
  plus tard — pas bloquant pour cette conception.

## 6. Hors périmètre pour cette conception

- Développement réel de l'app — ce document est une conception, pas un
  plan d'implémentation à exécuter immédiatement.
- Choix/achat du matériel de scan — décision de l'exploitant, pas une
  décision technique.
- Tout ce qui dépasse Pick/Pack/Ship pour cette v1 (réception fournisseur,
  inventaire physique — scénarios Shopfloor non retenus, voir §2).
- Contrôle qualité formel distinct (revue logistique : une checklist
  intégrée au Pack suffit pour ce commerce, pas un 4e scénario séparé).

## 7. Fichiers existants pertinents

- `docs/specs_preparation_groupee.md` §6 — la base déjà posée, complétée
  ici sans duplication.
- `CLAUDE.md` § Principe architecture Odoo, § Préparation groupée.
- `backend/addons/echango_order/models/batch_picking_engine.py`/
  `batch_picking_wizard.py` — le moteur de clustering (non exposé à l'app,
  §4.3) et le pattern `_candidate_orders()` dont le correctif backorder
  (§4.4) doit aussi bénéficier côté back-office existant, pas seulement
  côté app.
- `backend/addons/echango_order/controllers/order_controller.py` —
  `_prep_status()`, logique de statut à ne pas casser.
- `mobile/lib/` — conventions Flutter existantes (`errors/`, i18n,
  `provider`) — à dupliquer dans le nouveau projet plutôt qu'à mutualiser
  prématurément (§5).
