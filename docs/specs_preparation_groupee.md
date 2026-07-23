# Préparation groupée des commandes (batch picking + zone de tri)

Document de référence pour la fonctionnalité back-office de regroupement de
commandes en lots de préparation — voir `CLAUDE.md` § "Préparation groupée
des commandes" pour le résumé condensé (décision produit + justification
standard/custom). Ce document-ci détaille la conception complète et sert
surtout de **base pour la future app préparateur** (roadmap macro, hors
périmètre Phase 1/1.5 — voir `docs/specs_macro_drive_transport.md` §8).

Statut : conception validée et implémentée côté back-office Odoo
(2026-07-22), **non testée en réel** (pas de Docker dans le sandbox de
développement). L'app préparateur elle-même n'est pas commencée — ce
document liste ce qu'elle devra consommer une fois son développement
lancé.

## 1. Contexte et objectif

En attendant l'app préparateur dédiée, la préparation des commandes se
fait entièrement dans l'UI back-office Odoo standard. Besoin exprimé par
l'exploitant : les préparateurs perdent du temps à parcourir l'entrepôt
une fois par commande. Objectif : regrouper la collecte de plusieurs
commandes en une seule tournée (réduire les déplacements), puis séparer et
contrôler les produits collectés dans une **vraie zone de tri physique** —
poste dédié qui sert aussi au contrôle qualité et à la vérification de
quantité, pas seulement à séparer les commandes.

Cette conception a été challengée par 3 revues spécialisées indépendantes
avant tout codage (agents dédiés : logistique/entrepôt, Odoo/ERP
technique, algorithmique/optimisation). Le détail de ce qu'elles ont
trouvé et les corrections appliquées sont repris dans ce document, section
par section, plutôt qu'archivés à part.

## 2. Modèle Odoo — standard avant custom

**Route de livraison en 3 étapes (Pick + Pack + Ship)**, fonctionnalité
standard du module `stock` (confirmé disponible en Community, pas besoin
d'Enterprise) :

| Étape | Trajet | Rôle |
|---|---|---|
| **Pick** | Stock → Zone de tri | La collecte. Regroupable via `stock.picking.batch` (standard) sur plusieurs commandes — un seul passage dans l'entrepôt pour x commandes. |
| **Pack** | Zone de tri → Zone de sortie | La zone de tri physique demandée : contrôle qualité, vérification de quantité, séparation par commande. Usage conforme à la fonction native de cette étape dans Odoo, pas un détournement. |
| **Ship** | Zone de sortie → Client / comptoir retrait | Dernier maillon, inchangé — reste `picking_type_id.code == "outgoing"`, comme dans le flux à 1 étape historique. |

**Activation = configuration manuelle back-office**, pas de code : Réglages
→ Inventaire → activer "Multi-Step Routes", puis fiche Entrepôt →
Expéditions sortantes → "Réceptionner en zone de tri, puis expédier (3
étapes)". Même logique que `x_delivery_zone` (config métier, pas une
décision figée dans le module) — voir CLAUDE.md § Principe architecture
Odoo.

**Regroupement de commandes en un lot de collecte** : `stock.picking.batch`
(modèle standard), appliqué à l'étape Pick seulement.

**Suivi par commande individuelle au poste de tri** : `stock.package`
(modèle standard, mécanisme "Mettre en colis") — un bac/colis par commande.
Aucun champ standard ne relie `stock.package` à `sale.order` :
**convention de nommage** (`package.name = order.name`), pas de nouveau
champ custom. Le wizard (§4) crée ce package au moment de la création du
lot, mais son remplissage réel (quel produit va dans quel bac) reste un
geste manuel de l'opérateur pendant la collecte tant qu'il n'y a pas d'app
préparateur pour le scanner (voir §6).

**Ce qui est custom, et pourquoi** : uniquement le calcul du regroupement
optimal (§3) et l'assistant qui l'expose (§4) — Odoo standard n'a aucune
notion de similarité produit ni de contrainte de capacité multi-critères
pour le batching automatique (il ne sait grouper que par des critères
simples : même jour, même type d'opération).

## 3. Algorithme de composition des lots

Implémenté en pur Python, sans dépendance ORM, dans
`backend/addons/echango_order/models/batch_picking_engine.py`
(`compute_batches()`) — testé directement en sandbox (5 scénarios, voir §5)
puisqu'il n'a rien à mocker.

**Entrée** : commandes candidates = déjà confirmées (`sale.order.state ==
"sale"`, l'opérateur a cliqué "Confirmer" sur le devis), dont le picking
Pick existe, n'est pas terminé/annulé, et n'est pas déjà dans un lot.

**Contraintes dures** (configurables, voir §4 pour les valeurs par
défaut) :
- taille du lot ≤ nombre de bacs disponibles au poste de tri ;
- charge cumulée (quantité totale) ≤ capacité opérateur ;
- nombre de lignes cumulé ≤ plafond de temps de traitement au poste de tri
  (ajouté suite à la revue logistique — sans lui, un lot optimisé en
  déplacement peut créer un goulot d'étranglement au tri, le gain se
  transformant en attente devant le poste de contrôle).

**Boucle principale**, par fenêtre de temps compatible (bucket) :

1. Calculer une matrice de similarité de Jaccard (sur l'ensemble des
   `product_tmpl_id` des lignes, hors lignes de récompense) pour chaque
   paire de commandes du bucket — précalculée une fois, complexité O(N²),
   confirmée praticable à l'échelle du projet par la revue algorithmique.
2. **Règle fair-play** (résout le risque de famine identifié en revue) :
   si une commande dépasse un seuil SLA configurable sans avoir été
   affectée à un lot, elle devient **graine forcée** du prochain lot,
   indépendamment de son score de similarité — override dur, jugé plus
   explicable pour l'opérateur qu'un score composite pondéré.
3. Sinon, la graine est la commande dont la somme des similarités avec
   toutes les autres commandes **encore non affectées** est la plus forte
   (recalculée à chaque tour, pas une somme figée depuis le début — piège
   d'implémentation identifié en revue).
4. Croissance gloutonne : ajouter au lot la commande non affectée dont la
   similarité avec l'ensemble cumulé des produits du lot (compteur
   incrémental, pas recalculé depuis zéro) est la plus forte, sous réserve
   des contraintes dures ci-dessus **et** d'un seuil minimal de similarité
   configurable (ajouté suite à la revue algorithmique — sans lui, le
   glouton regrouperait des commandes sans aucun rapport dès que les
   contraintes de taille/charge le permettent).
5. **Tie-break déterministe** en cas d'égalité (ancienneté croissante puis
   id) — indispensable puisqu'un humain compare des suggestions d'un clic
   à l'autre (voir §4, validation humaine obligatoire).

## 4. L'assistant (wizard)

`backend/addons/echango_order/models/batch_picking_wizard.py` —
`x_batch_picking_wizard` (action de type **tableau de bord**, calcule sur
l'ensemble des commandes `sale` en attente, pas sur un enregistrement
précis via `active_id`) + `x_batch_picking_wizard_line` (une ligne par
commande candidate, numéro de lot suggéré **éditable par l'opérateur**
avant validation).

Garder un humain dans la boucle est une décision produit assumée pour
cette v1 : aucun retour terrain mesuré à ce stade, une automatisation
totale et silencieuse est jugée risquée. Bouton "Créer les lots" :
matérialise les `stock.picking.batch` réels (un par valeur distincte de
`batch_index`) + un `stock.package` par commande.

**Navigation Pick → Pack — trouvaille en test réel (2026-07-22), puis décision produit** :
en testant le parcours de bout en bout, aucun mécanisme standard ne relie
le lot de collecte (Pick) à ses transferts Pack correspondants une fois
la collecte validée — ni Batch ni Wave Transfers (confirmé contre la doc
Odoo officielle : "Wave transfers can only contain product lines from
transfers of the same operation type", donc jamais Pick+Pack mélangés).
Sans rien faire, l'opérateur de tri doit retrouver chaque commande une par
une. Trois options comparées :

1. **Un 2e `stock.picking.batch` automatique pour le Pack** (implémenté
   puis retiré) : `action_create_batches()` aurait résolu, pour les mêmes
   commandes, leurs transferts Pack (via `order.warehouse_id.pack_type_id`,
   même schéma que `pick_type_id`) et les aurait regroupés dans un second
   lot ("Tri — lot N"). Toujours du standard (une 2e utilisation de
   `stock.picking.batch`, pas de nouveau modèle), mais complexité jugée
   pas prioritaire à ce stade par l'utilisateur — retiré.
2. **Module OCA `stock_picking_show_linked`** (dépôt
   `stock-logistics-warehouse`, confirmé porté en 19.0, AGPL-3, dépend
   uniquement de `stock`) : bouton de navigation d'un picking chaîné à
   l'autre. Écarté : reste une navigation commande par commande (pas une
   vue de liste par lot), et ajoute une dépendance externe à récupérer et
   déployer (pas juste `-u echango_order`) pour un gain jugé secondaire.
3. **Rien — recherche standard, retenue pour cette v1** : Inventaire >
   Transferts, filtrer sur "Document d'origine" = référence de la
   commande. Vérifié en test réel : `stock.picking.origin` est un simple
   champ texte, pas cliquable ni dans la liste des transferts d'un lot, ni
   sur la fiche d'un transfert individuel — mais la recherche reste rapide
   (2 clics) et ne nécessite aucun code ni dépendance. Décision produit
   (2026-07-22) : suffisant pour l'usage back-office actuel, à revisiter
   si le volume de commandes rend cette recherche manuelle trop lente.

**Paramètres réglables** (`ir.config_parameter`, `data/batch_picking_data.xml`
— pas de nouveau modèle pour quelques scalaires) :

| Clé | Rôle | Défaut |
|---|---|---|
| `echango_order.batch_max_orders` | Bacs disponibles au poste de tri | 6 |
| `echango_order.batch_max_qty` | Charge opérateur (quantité cumulée) | 100 |
| `echango_order.batch_max_lines` | Plafond temps de traitement au tri | 40 |
| `echango_order.batch_min_similarity` | Seuil minimal de similarité | 0.10 |
| `echango_order.batch_sla_hours` | Fair-play (ancienneté avant override) | 4h |

Valeurs par défaut arbitraires, non calibrées sur des données réelles — à
ajuster une fois le volume réel de commandes observé (point explicitement
laissé ouvert avec l'utilisateur, "ajuster plus tard").

**Réglables depuis l'UI Odoo** (`models/batch_picking_settings_wizard.py`,
assistant dédié — formulaire sous un menu "Paramètres de préparation
groupée", en dehors du formulaire général de l'app Réglages) : ajouté
suite à un retour utilisateur en test réel, le mode développeur (Réglages
> Technique > Paramètres système) était jugé peu accessible pour un usage
courant.

**Essai initial abandonné** : d'abord implémenté via une extension de
`res.config.settings` (mécanisme standard `config_parameter=...`, aucun
code de lecture/écriture). Bug trouvé en test réel : Odoo traite ce modèle
spécialement et l'ouvre toujours dans la coquille complète de l'app
Réglages (barre "Settings > General Settings > ...") au lieu d'un simple
dialogue — impossible de revenir à l'écran d'origine une fois ouvert.
Remplacé par un `TransientModel` ordinaire (même pattern fiable que
`x_batch_picking_wizard`) : lecture/écriture explicite de
`ir.config_parameter` dans `default_get()`/`action_save()`. Résout au
passage le point de vigilance précédent sur l'accès (`res.config.settings`
est réservé par défaut au groupe Réglages `base.group_system` — plus
d'objet, le nouvel assistant est en `base.group_user` comme les autres
menus internes du module).

## 5. Compatibilité avec le suivi client existant (F08)

`order_controller.py._prep_status()` filtrait historiquement uniquement le
picking `outgoing` (flux à 1 étape). Sur une route à 3 étapes, ce picking
reste `waiting`/`confirmed` tant que le Pack n'est pas validé — sans
correction, le statut app serait resté bloqué sur "pending" pendant toute
la collecte et le tri, alors qu'un opérateur y travaille activement.

**Corrigé** : `_prep_status()` regarde désormais tous les pickings actifs
de la commande — "in_progress" se déclenche dès qu'un opérateur s'assigne
n'importe quel picking de la chaîne (Pick, Pack ou Ship). "completed" reste
dérivé du seul picking Ship. Décision produit : pas de nouveau palier de
statut app ("en cours de tri") pour cette v1 — perte de précision assumée
côté client final, voir §6 pour la granularité que l'app préparateur devra
elle exposer en interne.

Rétrocompatible : sur un entrepôt resté à 1 étape, `_prep_status()` se
comporte exactement comme avant (aucun picking Pick/Pack à considérer).

**Bug trouvé au premier test réel (2026-07-22)** : `AttributeError:
'stock.picking' object has no attribute 'batch_id'` à l'ouverture du
wizard. Confirmé contre le code source Odoo 19 : `batch_id` n'est PAS
défini dans le module `stock` de base (contrairement à l'hypothèse
initiale de la revue Odoo — l'erreur d'origine dans cette revue), mais
dans un module séparé `stock_picking_batch` (Community, LGPL-3, dépend
uniquement de `stock`), jamais déclaré dans les dépendances du module
`echango_order`. Corrigé (`__manifest__.py`) — nécessite `-u echango_order`
pour qu'Odoo installe cette dépendance manquante.

**2e bug trouvé au test réel (2026-07-22)** : `NotNullViolation` sur
`order_id` à la sauvegarde du wizard — le client web n'envoie pas les
champs `readonly="1"` peuplés seulement via `default_get` (pas un vrai
`compute`) lors de la création des lignes d'un One2many éditable.
`force_save="1"` (mécanisme standard prévu pour ce cas) s'est avéré
**insuffisant** ici et l'erreur a persisté. Corrigé en profondeur :
`order_id`/`line_count`/`qty_total` sur `x_batch_picking_wizard_line`
sont devenus des champs **calculés** (`compute`, `store=True`),
dépendants uniquement de `picking_id` (résolu via `stock.picking.sale_id`,
champ standard du module `sale_stock`) — seul `picking_id` (non
`readonly`) survit de façon fiable à la sauvegarde côté client ; Odoo
recalcule le reste côté serveur, sans dépendre de ce que le client
retransmet.

Tests exécutés (moteur de clustering uniquement, pur Python) :
regroupement par similarité, seuil minimal, plafond de bacs, règle
fair-play, déterminisme — tous passés. Le wizard lui-même (collecte des
données réelles Odoo, création des `stock.picking.batch`/packages) n'a pas
pu être testé faute de Docker dans ce sandbox.

## 6. Pour l'app préparateur (futur) — ce que ce backend devra exposer

L'app préparateur n'existe pas encore (roadmap macro, après Phase 1.5).
Cette section fige ce que la conception actuelle du backend implique pour
sa future conception, pour éviter d'avoir à re-découvrir ces contraintes
plus tard.

### 6.1 Écrans/parcours pressentis (à valider avec l'utilisateur le moment venu)

1. **Liste des lots à traiter** — un opérateur choisit un lot
   (`stock.picking.batch`) parmi ceux qui lui sont assignés ou disponibles.
2. **Collecte guidée** — liste de prélèvement du lot, triée par
   emplacement de stockage (une fois les emplacements précis en place,
   voir §7) plutôt que par commande — c'est le cœur du gain de
   déplacement recherché. Chaque article scanné/coché devrait indiquer
   dans quel bac/commande il va (voir `stock.package`, §2).
3. **Poste de tri** — vue par commande du lot : liste attendue vs. liste
   collectée, validation quantité par quantité (le contrôle qualité
   demandé), fermeture du colis.
4. **Transfert final** — passage à l'étape Ship (inchangé par rapport au
   flux actuel à 1 étape, déjà couvert par `_prep_status()`/F08).

### 6.2 Modèle de données à exposer côté API

L'app cliente actuelle n'expose que 3 statuts (pending/in_progress/
completed, voir §5) — **volontairement pauvre**, pensé pour un client
final. L'app préparateur aura besoin d'un niveau de détail bien supérieur,
probablement via de nouveaux contrôleurs dédiés (pas les mêmes que
`/echango/order/*`, pensés pour le portail client) :

- `stock.picking.batch` : id, nom, état, liste des `stock.picking` membres.
- `stock.picking` (par étape Pick/Pack/Ship) : état, `user_id`
  (responsable), lignes de mouvement (`stock.move.line` : produit,
  quantité, emplacement source/destination).
- `stock.package` : nom (= référence commande, voir §2), contenu.
- `sale.order` : référence, `x_reception_mode`, `x_creneau` — déjà exposés
  côté client (F08/F09), réutilisables tels quels côté préparateur.

### 6.3 Scan code-barres — exigence confirmée (2026-07-22, échange avec l'utilisateur)

Besoin explicite : l'opérateur doit pouvoir **scanner les produits** (pas de saisie manuelle) à deux moments — pendant la collecte groupée (Pick, confirmer chaque article prélevé) et pendant la mise en bac (Pack, affecter au bon `stock.package`) — objectif : éliminer les erreurs de frappe, pas juste un confort.

**Recherché et écarté pour un usage immédiat (avant l'app préparateur)** :
- **App "Code-barres" native d'Odoo** (`stock_barcode`) : confirmée **Enterprise uniquement** — absente du dépôt Community (`odoo/odoo` public, vérifié directement, 404 sur `addons/stock_barcode`). Pas d'équivalent en Community pour l'instant.
- **Alternative OCA** (`stock_barcodes`, dépôt `OCA/stock-logistics-barcode`) : existe mais **s'arrête à la version 16.0** (404 confirmés sur les branches 18.0 et 19.0) — pas porté sur Odoo 19, inutilisable sans un vrai travail de portage.
- Des apps tierces payantes existent sur l'Odoo Apps Store (non vérifiées pour la 19.0) — décision commerciale/fournisseur, pas tranchée.

**Conclusion** : pas de solution de scan gratuite et à jour pour Odoo 19 Community aujourd'hui, ni native ni OCA. Le scan devra donc être **construit dans l'app préparateur elle-même** (caméra du téléphone côté Flutter — ex. package `mobile_scanner` ou équivalent — plutôt que de dépendre de l'app Barcode d'Odoo), appelant de nouveaux endpoints `/echango/*` dédiés aux opérateurs internes (voir §6.2/§6.4 pour le modèle de données). Cette décision élimine aussi la dépendance à Enterprise ou à un module OCA non maintenu pour la version cible.

### 6.4 Question ouverte — authentification préparateur

L'app cliente utilise téléphone + PIN (F02, mécanisme custom `x_pin` sur
`res.users`, groupe portail). Les préparateurs sont des **utilisateurs
internes** (`base.group_user`, pas `base.group_portal`) — l'authentification
de l'app préparateur devra probablement réutiliser la connexion standard
Odoo (login/mot de passe interne), pas le mécanisme téléphone/PIN pensé
spécifiquement pour des clients. **Non tranché, à décider au lancement de
ce chantier.**

### 6.5 Risques connus à ne pas re-découvrir plus tard

- **Tension similarité produit / risque d'erreur de tri** (remontée par la
  revue logistique, non résolue) : un lot à forte similarité (beaucoup
  d'exemplaires identiques à répartir entre commandes) est un terrain
  propice à la confusion de bac. L'app préparateur devrait probablement
  imposer une vérification renforcée (scan systématique du bac de
  destination, pas seulement du produit) plutôt que de faire confiance à
  la mémoire de l'opérateur — à concevoir avec un vrai retour terrain.
- **Gestion des exceptions pendant un lot en cours** (rupture de stock
  découverte à mi-collecte) : non pensé du tout dans la conception
  actuelle — lien probable avec F17 (substitution, aujourd'hui géré côté
  client *avant* confirmation) à retravailler pour le cas d'un lot déjà en
  cours de traitement.
- **Chaîne du froid / frais-surgelé** : explicitement hors périmètre pour
  cette v1 (catalogue actuel sans contrainte de température) — si le
  catalogue évolue, l'app préparateur devra probablement imposer un ordre
  de traitement (frais en dernier au Pick, en premier au Pack) que le
  moteur de clustering actuel ignore totalement.

## 7. Autres points ouverts (backend, indépendants de l'app préparateur)

- Seuil exact de "fenêtre de temps compatible" entre commandes d'un même
  lot (même créneau strict ? tolérance en heures ? même jour minimum ?).
- Définition affinée de la "charge opérateur" (aujourd'hui : quantité
  brute cumulée — pas de poids/volume par produit dans ce projet).
- Pondération par emplacement de stockage précis une fois ces emplacements
  en place (aujourd'hui : similarité produit pure, `product_tmpl_id`,
  emplacements ignorés).
- Fréquence de calcul des suggestions (à la demande via le bouton
  "Recalculer", ou cron périodique ?).
