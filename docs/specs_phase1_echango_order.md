# Specs Détaillées — Echango Order Phase 1 MVP

**Version** : 1.0  
**Statut** : v1.5 — Reorder 1 tap, zone livraison, sécurité HTTPS/session/PIN device, post-MVP enrichi  
**Agents** : Product Owner · UX Designer · Expert Odoo · QA Engineer  
**Périmètre** : App mobile client React Native (iOS & Android) — Bilingue FR/AR

---

## 1. Contexte & Objectifs

### 1.1 Objectif Phase 1
Livrer une app mobile client permettant de commander des produits alimentaires, choisir entre livraison à domicile ou retrait en magasin, et suivre l'état de sa commande. Paiement uniquement à la réception ou au retrait.

### 1.2 Stack technique
- **Frontend** : React Native (iOS & Android)
- **Backend** : Odoo 19 (APIs JSON-RPC)
- **Notifications** : Firebase Cloud Messaging
- **Paiement** : Cash à la réception / au retrait (aucune intégration paiement en ligne)
- **Langues** : Français + Arabe (RTL natif)

### 1.3 Contraintes
- Développement custom Odoo limité : endpoint auth téléphone/PIN + rate limiting vitrine publique
- Paiement en ligne hors périmètre MVP
- GPS temps réel hors périmètre MVP
- Opérations (préparation + livraison) gérées manuellement en Phase 1

---

## 2. Parcours Utilisateur Global

```
Ouverture app
      ↓
F00 — Vitrine publique (sans compte, navigation libre)
      ↓
Clic "Ajouter au panier" → Popup invitation inscription
      ↓
F01 — Onboarding (1ère fois) → Skippable
      ↓
Authentification (inscription téléphone+PIN / connexion / invité)
      ↓
Accueil (produits mis en avant + catégories)
      ↓
Catalogue → Recherche → Fiche produit
      ↓
Panier → Checkout
      ↓
Choix mode réception (livraison / retrait)
      ↓
Choix créneau horaire
      ↓
Récapitulatif → Confirmation commande
      ↓
Suivi statuts + Notifications push
      ↓
Historique commandes
```

---

## 3. Fonctionnalités Détaillées

---

### F01 — Onboarding

**Product Owner — User Story**
> En tant que nouvel utilisateur, je veux découvrir rapidement les fonctionnalités clés de l'app afin de comprendre ce que je peux faire avant de m'inscrire.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│  [Logo Echango Order]   │
│                         │
│  [Illustration]         │
│                         │
│  Commandez vos          │
│  produits locaux        │
│  en quelques clics      │
│                         │
│  ● ○ ○  (3 slides)     │
│                         │
│  [Suivant]              │
│  [Passer →]             │
└─────────────────────────┘
```
- 3 slides maximum : Commander / Choisir retrait ou livraison / Suivre sa commande
- Bouton "Passer" visible dès le premier slide
- Disponible en FR et AR (RTL)
- Affiché uniquement à la première ouverture

**Expert Odoo — API**
- Aucun appel API nécessaire

**QA — Critères d'acceptation**
- [ ] L'onboarding s'affiche uniquement à la première ouverture
- [ ] Le bouton "Passer" est fonctionnel dès le slide 1
- [ ] Navigation entre slides par swipe et bouton
- [ ] L'onboarding est correctement affiché en AR (RTL)
- [ ] Après l'onboarding, redirection vers l'écran d'authentification

---

### F02 — Authentification

**Product Owner — User Story**
> En tant qu'utilisateur, je veux m'inscrire avec mon numéro de téléphone et un code PIN, me connecter rapidement ou commander sans compte afin d'accéder à l'app simplement.

**UX Designer — Wireframe**
```
Écran d'accueil auth :
┌─────────────────────────┐
│  Bienvenue              │
│                         │
│  [S'inscrire]           │
│  [Se connecter]         │
│                         │
│  ───── ou ─────         │
│                         │
│  [Continuer sans        │
│   compte →]             │
└─────────────────────────┘

Inscription — Étape 1 (infos) :
┌─────────────────────────┐
│  Prénom    [________]   │
│  Nom       [________]   │
│  Téléphone [+213_____]  │
│                         │
│  Langue :  [FR] [AR]    │
│                         │
│  📍 [Ajouter ma         │
│      localisation]      │
│                         │
│  ☐ J'accepte les CGU   │
│    et la politique de   │
│    confidentialité      │
│                         │
│  [Continuer →]          │
└─────────────────────────┘

Inscription — Étape 2 (adresse) :
┌─────────────────────────┐
│  Adresse de livraison   │
│                         │
│  Rue      [__________]  │
│  Ville    [__________]  │
│  Code     [__________]  │
│                         │
│  ── ou ──               │
│                         │
│  📍 [Utiliser ma        │
│      position GPS]      │
│                         │
│  [Continuer →]          │
│  [Passer cette étape]   │
└─────────────────────────┘

Inscription — Étape 3 (PIN) :
┌─────────────────────────┐
│  Créez votre code PIN   │
│                         │
│  [●][●][●][●]           │
│                         │
│  Confirmez votre PIN    │
│                         │
│  [●][●][●][●]           │
│                         │
│  [Créer mon compte]     │
└─────────────────────────┘

Connexion :
┌─────────────────────────┐
│  Téléphone [+213_____]  │
│                         │
│  Code PIN  [●][●][●][●] │
│                         │
│  [PIN oublié ?]         │
│                         │
│  [Se connecter]         │
└─────────────────────────┘

PIN oublié :
┌─────────────────────────┐
│  Entrez votre numéro    │
│  de téléphone           │
│                         │
│  Téléphone [+213_____]  │
│                         │
│  [Recevoir un SMS]      │
│                         │
│  SMS reçu :             │
│  Code [____]            │
│  [Nouveau PIN]          │
└─────────────────────────┘
```

**Expert Odoo — API**
- Inscription : `POST /web/dataset/call_kw` → model `res.users`, method `create`
  - Champs : `name`, `phone`, `x_pin` (hashé), `x_langue`, `x_adresse_favorite`
- Connexion : authentification par téléphone + PIN via endpoint custom
- PIN oublié : envoi SMS via provider (ex: Twilio) → nouveau PIN
- Localisation GPS : stockée sur `res.partner`, champs `x_latitude`, `x_longitude`
- Adresse favorite : champ `x_adresse_favorite` sur `res.partner`
- Mode invité : commande liée à un partner temporaire Odoo

**QA — Critères d'acceptation**
- [ ] Inscription avec prénom, nom, téléphone, langue, PIN
- [ ] Validation format numéro de téléphone (format local)
- [ ] Message d'erreur clair si numéro déjà utilisé
- [ ] PIN de 4 chiffres, confirmation obligatoire
- [ ] Erreur si PIN confirmation différent
- [ ] Bouton localisation GPS fonctionnel et optionnel
- [ ] Adresse de livraison pré-remplie si GPS activé
- [ ] Étape adresse skippable
- [ ] Case CGU et politique confidentialité obligatoire avant validation
- [ ] Lien CGU et politique confidentialité ouvrent les pages correspondantes
- [ ] Connexion avec téléphone + PIN fonctionnelle
- [ ] PIN oublié → SMS de réinitialisation
- [ ] Session persistante (rester connecté)
- [ ] Option invité disponible et fonctionnelle
- [ ] Déconnexion disponible depuis le profil
- [ ] Tous les écrans disponibles en FR et AR (RTL)

---

### F03 — Accueil

**Product Owner — User Story**
> En tant qu'utilisateur connecté, je veux voir une page d'accueil claire avec les produits mis en avant et les catégories disponibles afin de commencer mes achats rapidement.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│ [🔍 Rechercher...]  [👤]│
│                         │
│ ┌─────────────────────┐ │
│ │  Bannière promo     │ │
│ └─────────────────────┘ │
│                         │
│ Catégories              │
│ [🥩][🥦][🥛][🍞][+]   │
│                         │
│ Produits du moment      │
│ ┌────┐ ┌────┐ ┌────┐   │
│ │    │ │    │ │    │   │
│ │Prod│ │Prod│ │Prod│   │
│ └────┘ └────┘ └────┘   │
│                         │
│ [🏠] [📋] [🛒²] [👤]  │  ← badge nombre articles
└─────────────────────────┘
```
- Barre de recherche en haut
- Bannière promotionnelle (configurable Odoo)
- Grille de catégories horizontale scrollable
- Section produits mis en avant
- Barre de navigation fixe en bas (Accueil / Catalogue / Panier / Profil)

**Expert Odoo — API**
- Catégories : `GET /web/dataset/call_kw` → model `product.category`, method `search_read`
- Produits mis en avant : `GET /web/dataset/call_kw` → model `product.template`, method `search_read`, filter `is_published = true`
- Bannière : champ custom configurable en back-office Odoo

**QA — Critères d'acceptation**
- [ ] Page d'accueil chargée en moins de 2 secondes
- [ ] Catégories affichées et cliquables
- [ ] Produits mis en avant affichés avec photo, nom et prix
- [ ] Barre de recherche fonctionnelle depuis l'accueil
- [ ] Navigation barre du bas fonctionnelle
- [ ] Affichage correct en FR et AR (RTL)
- [ ] Gestion du cas "aucun produit disponible"

---

### F04 — Catalogue & Recherche

**Product Owner — User Story**
> En tant qu'utilisateur, je veux naviguer dans le catalogue par catégorie et rechercher un produit par nom afin de trouver rapidement ce que je cherche.

**UX Designer — Wireframe**
```
Catalogue par catégorie :
┌─────────────────────────┐
│ ← Fruits & Légumes      │
│ [🔍 Rechercher...]      │
│                         │
│ ┌──────┐  ┌──────┐     │
│ │ img  │  │ img  │     │
│ │Pommes│  │Tomates│    │
│ │2.50€ │  │1.80€ │     │
│ │ [+]  │  │ [+]  │     │
│ └──────┘  └──────┘     │
│                         │
│ ┌──────┐  ┌──────┐     │
│ │ img  │  │ img  │     │
│ └──────┘  └──────┘     │
└─────────────────────────┘

Recherche :
┌─────────────────────────┐
│ ← [🔍 lait...      ] ✕ │
│                         │
│ Résultats (3)           │
│                         │
│ ┌──────────────────┐    │
│ │img│ Lait entier  │    │
│ │   │ 1.20€    [+] │    │
│ └──────────────────┘    │
│ ┌──────────────────┐    │
│ │img│ Lait demi... │    │
│ │   │ 1.10€    [+] │    │
│ └──────────────────┘    │
└─────────────────────────┘
```

**Expert Odoo — API**
- Liste produits par catégorie : `search_read` sur `product.template` filtré par `categ_id`
- Recherche : `search_read` sur `product.template` avec filtre `name ilike`
- Disponibilité stock : champ `qty_available` sur `product.template`
- Prix : champ `list_price`
- Images : champ `image_1920`

**QA — Critères d'acceptation**
- [ ] Navigation par catégorie fonctionnelle
- [ ] Affichage grille produits avec photo, nom, prix
- [ ] Produit épuisé clairement indiqué (grisé / badge)
- [ ] Recherche par nom retourne les bons résultats
- [ ] Résultat vide géré avec message approprié
- [ ] Ajout au panier depuis la liste produits
- [ ] Affichage correct en FR et AR (RTL)

---

### F05 — Fiche Produit

**Product Owner — User Story**
> En tant qu'utilisateur, je veux voir le détail d'un produit avec sa photo, description et prix afin de décider si je l'ajoute à mon panier.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│ ←                   🛒 │
│                         │
│ ┌─────────────────────┐ │
│ │                     │ │
│ │      [Photo]        │ │
│ │                     │ │
│ └─────────────────────┘ │
│                         │
│ Nom du produit          │
│ Marque / Origine        │
│                         │
│ 2.50 € / kg             │
│                         │
│ Description complète    │
│ du produit...           │
│                         │
│ Quantité :  [-] 1 [+]  │
│                         │
│ [Ajouter au panier]     │
└─────────────────────────┘
```

**Expert Odoo — API**
- Détail produit : `search_read` sur `product.template` par id
- Champs : `name`, `description`, `list_price`, `image_1920`, `qty_available`, `uom_id` (unité)

**QA — Critères d'acceptation**
- [ ] Photo produit affichée en haute qualité
- [ ] Nom, prix, unité et description affichés
- [ ] Sélecteur de quantité fonctionnel (min 1)
- [ ] Bouton "Ajouter au panier" fonctionnel
- [ ] Si produit épuisé : bouton désactivé avec message
- [ ] Affichage correct en FR et AR (RTL)

---

### F06 — Panier

**Product Owner — User Story**
> En tant qu'utilisateur, je veux consulter et modifier mon panier avant de passer commande afin de vérifier ma sélection et le montant total.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│ ← Mon Panier (3)        │
│                         │
│ ┌──────────────────┐    │
│ │img│ Pommes       │    │
│ │   │ 2.50€/kg     │    │
│ │   │ [-] 2kg [+] 🗑│   │
│ └──────────────────┘    │
│ ┌──────────────────┐    │
│ │img│ Lait entier  │    │
│ │   │ 1.20€        │    │
│ │   │ [-] 1  [+] 🗑│   │
│ └──────────────────┘    │
│                         │
│ ─────────────────────   │
│ Sous-total :   6.20€    │
│ Livraison :    2.00€    │
│ **Total :      8.20€**  │
│                         │
│ [Valider mon panier]    │
└─────────────────────────┘
```

**Expert Odoo — API**
- Création commande : `create` sur `sale.order`
- Ajout ligne : `create` sur `sale.order.line`
- Mise à jour quantité : `write` sur `sale.order.line`
- Suppression ligne : `unlink` sur `sale.order.line`
- Prix livraison : configurable Odoo selon mode de réception

**QA — Critères d'acceptation**
- [ ] Liste des produits ajoutés avec photo, nom, prix, quantité
- [ ] Modification de quantité depuis le panier
- [ ] Suppression d'un produit depuis le panier
- [ ] Sous-total, frais de livraison et total affichés
- [ ] Panier vide géré avec message + lien vers catalogue
- [ ] Bouton "Valider" mène au checkout
- [ ] Panier persistant entre les sessions
- [ ] Affichage correct en FR et AR (RTL)

---

### F07 — Checkout & Mode de Réception

**Product Owner — User Story**
> En tant qu'utilisateur, je veux choisir entre la livraison à domicile et le retrait en magasin, sélectionner un créneau horaire, et confirmer ma commande afin de finaliser mon achat.

**UX Designer — Wireframe**
```
Étape 1 — Mode de réception :
┌─────────────────────────┐
│ ← Réception             │
│                         │
│ ┌─────────────────────┐ │
│ │ 🏠 Livraison        │ │
│ │    à domicile    ◉  │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 🏪 Retrait          │ │
│ │    en magasin    ○  │ │
│ └─────────────────────┘ │
│                         │
│ [Continuer →]           │
└─────────────────────────┘

Étape 2 — Adresse (si livraison) :
┌─────────────────────────┐
│ ← Adresse livraison     │
│                         │
│ Rue      [___________]  │
│ Ville    [___________]  │
│ Code     [___________]  │
│ Notes    [___________]  │
│                         │
│ 📍 [Utiliser ma         │
│     position GPS]       │
│                         │
│ [Continuer →]           │
└─────────────────────────┘

Hors zone de livraison :
┌─────────────────────────┐
│  ❌ Zone non couverte   │
│                         │
│  Votre adresse n'est    │
│  pas encore dans notre  │
│  zone de livraison.     │
│                         │
│  Vous pouvez choisir    │
│  le retrait en magasin. │
│                         │
│  [Retrait en magasin]   │
│  [Modifier l'adresse]   │
└─────────────────────────┘

Étape 3 — Créneau :
┌─────────────────────────┐
│ ← Créneau               │
│                         │
│ Aujourd'hui             │
│ ○ 10h00 - 12h00         │
│ ◉ 14h00 - 16h00         │
│ ○ 16h00 - 18h00         │
│                         │
│ Demain                  │
│ ○ 09h00 - 11h00         │
│ ○ 11h00 - 13h00         │
│                         │
│ [Continuer →]           │
└─────────────────────────┘

Étape 4 — Récapitulatif :
┌─────────────────────────┐
│ ← Récapitulatif         │
│                         │
│ 📦 3 articles — 8.20€   │
│ 🏠 Livraison à domicile │
│ 🕐 Aujourd'hui 14h-16h  │
│ 💵 Paiement réception   │
│                         │
│ [Confirmer la commande] │
└─────────────────────────┘
```

**Expert Odoo — API**
- Mise à jour commande : `write` sur `sale.order`
  - Champ mode réception : custom field `x_reception_mode` (livraison / retrait)
  - Champ adresse : `partner_shipping_id`
  - Champ créneau : custom field `x_creneau`
- Créneaux disponibles : custom field configuré en back-office Odoo
- Zones de livraison : `search_read` sur custom model `x_delivery_zone` (code postal / ville)
- Vérification zone : comparaison adresse saisie vs zones configurées en back-office
- Confirmation commande : `write` sur `sale.order`, champ `state` → `sale`

**QA — Critères d'acceptation**
- [ ] Choix livraison ou retrait en magasin
- [ ] Saisie adresse de livraison si mode livraison sélectionné
- [ ] Adresse obligatoire validée avant de continuer
- [ ] Affichage des créneaux disponibles
- [ ] Créneau complet grisé et non sélectionnable
- [ ] Récapitulatif complet avant confirmation
- [ ] Mention "Paiement à la réception / au retrait" visible
- [ ] Confirmation commande crée la commande dans Odoo
- [ ] Vérification zone de livraison après saisie adresse
- [ ] Message clair si adresse hors zone avec proposition retrait en magasin
- [ ] Adresse GPS pré-remplit les champs automatiquement
- [ ] Affichage correct en FR et AR (RTL)

---

### F08 — Confirmation & Suivi Commande

**Product Owner — User Story**
> En tant qu'utilisateur, je veux recevoir une confirmation de ma commande et suivre son état en temps réel afin d'être informé à chaque étape jusqu'à la réception.

**UX Designer — Wireframe**
```
Confirmation :
┌─────────────────────────┐
│                         │
│       ✅                │
│  Commande confirmée !   │
│  Réf : ECH-2026-0042   │
│                         │
│  Livraison aujourd'hui  │
│  entre 14h et 16h       │
│                         │
│  Paiement à la          │
│  réception : 8.20€      │
│                         │
│  [Suivre ma commande]   │
│  [Retour accueil]       │
└─────────────────────────┘

Suivi commande :
┌─────────────────────────┐
│ ← Commande #ECH-0042    │
│                         │
│ ✅ Commande confirmée   │
│ 🔄 En cours préparation │
│ ○  Prête                │
│ ○  En livraison         │
│ ○  Livrée               │
│                         │
│ Créneau : 14h00-16h00   │
│ Total : 8.20€ (espèces) │
│                         │
│ Articles (3)            │
│ • Pommes x2kg           │
│ • Lait entier x1        │
│ • ...                   │
└─────────────────────────┘
```

**Expert Odoo — API**
- Statut commande : `search_read` sur `sale.order` par id, champ `state`
- Statut livraison : `search_read` sur `stock.picking`, champ `state`
- Notifications push : Firebase → déclenché par changement de statut Odoo
- Statuts synchronisés :
  - `sale` → Confirmée / En préparation
  - `ready` (custom) → Prête à retirer / Prête à livrer
  - `ready` (custom) → Prête
  - `assigned` (custom) → En livraison
  - `done` → Livrée / Retirée en magasin
  - `cancel` → Annulée

**QA — Critères d'acceptation**
- [ ] Écran de confirmation affiché après validation commande
- [ ] Numéro de référence commande visible
- [ ] Récapitulatif créneau et montant visible
- [ ] Suivi statuts en temps réel dans l'app
- [ ] Notification push à chaque changement de statut
- [ ] Statut actuel mis en évidence dans le fil de suivi
- [ ] Détail des articles commandés visible
- [ ] Statut annulée affiché correctement si commande annulée
- [ ] Distinction visuelle retrait en magasin vs livraison dans le fil de suivi
- [ ] Affichage correct en FR et AR (RTL)

---

### F09 — Historique Commandes & Reorder

**Product Owner — User Story**
> En tant qu'utilisateur, je veux accéder à l'historique de mes commandes et pouvoir recommander en un seul tap afin de gagner du temps sur mes achats habituels.

**UX Designer — Wireframe**
```
Liste commandes :
┌─────────────────────────┐
│ ← Mes commandes         │
│                         │
│ ┌──────────────────────┐ │
│ │ #ECH-0042            │ │
│ │ 15 juillet 2026      │ │
│ │ 8.20€  ✅ Livrée     │ │
│ │ [Commander à nouveau]│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ #ECH-0038            │ │
│ │ 10 juillet 2026      │ │
│ │ 12.50€ ✅ Livrée     │ │
│ │ [Commander à nouveau]│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ #ECH-0031            │ │
│ │ 2 juillet 2026       │ │
│ │ 6.00€  🔄 En cours   │ │
│ └──────────────────────┘ │
└─────────────────────────┘

Popup reorder :
┌─────────────────────────┐
│  🛒 Commander à nouveau ?│
│                         │
│  3 articles de la       │
│  commande #ECH-0042     │
│  seront ajoutés à       │
│  votre panier.          │
│                         │
│  ⚠️  Certains produits  │
│  peuvent ne plus être   │
│  disponibles.           │
│                         │
│  [Ajouter au panier]    │
│  [Annuler]              │
└─────────────────────────┘
```
- Bouton "Commander à nouveau" visible sur chaque commande livrée
- Popup de confirmation avant ajout au panier
- Avertissement si certains produits ne sont plus disponibles
- Produits indisponibles exclus automatiquement du panier
- Redirige vers le panier après ajout

**Expert Odoo — API**
- Liste commandes : `search_read` sur `sale.order` filtré par `partner_id` = utilisateur connecté
- Champs : `name`, `date_order`, `amount_total`, `state`
- Détail commande (reorder) : `search_read` sur `sale.order.line` filtré par `order_id`
- Vérification disponibilité produits : `search_read` sur `product.template`, champ `qty_available`
- Création nouveau panier : `create` sur `sale.order` + `sale.order.line` avec les produits disponibles

**QA — Critères d'acceptation**
- [ ] Liste de toutes les commandes de l'utilisateur
- [ ] Date, référence, montant et statut visibles
- [ ] Commandes triées par date décroissante
- [ ] Clic sur une commande ouvre le détail
- [ ] Bouton "Commander à nouveau" visible uniquement sur commandes livrées
- [ ] Popup de confirmation affiché avant ajout au panier
- [ ] Produits disponibles ajoutés au panier correctement
- [ ] Produits indisponibles exclus avec message informatif
- [ ] Redirection vers le panier après reorder
- [ ] Commandes en cours affichent le suivi actif sans bouton reorder
- [ ] Gestion cas "aucune commande" avec message approprié
- [ ] Utilisateur invité : message invitant à créer un compte pour accéder à l'historique
- [ ] Affichage correct en FR et AR (RTL)

---

### F10 — Profil Utilisateur

**Product Owner — User Story**
> En tant qu'utilisateur, je veux gérer mon profil, mes adresses et mes préférences afin de personnaliser mon expérience et gagner du temps lors des prochaines commandes.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│ ← Mon Profil            │
│                         │
│ 👤 Prénom Nom           │
│    +213 XX XX XX XX     │
│                         │
│ ─────────────────────   │
│ 📍 Mes adresses    ›    │
│ 📍 Ma localisation ›    │
│ 🔑 Modifier PIN    ›    │
│ 🔔 Notifications   ›    │
│ 🌐 Langue (FR/AR)  ›    │
│                         │
│ ─────────────────────   │
│ 📋 Mes commandes   ›    │
│ ℹ️  À propos        ›    │
│ 📄 CGU             ›    │
│ 🔒 Confidentialité ›    │
│                         │
│ ─────────────────────   │
│ [Se déconnecter]        │
│                         │
│ [Supprimer mon compte]  │
└─────────────────────────┘

Popup suppression compte :
┌─────────────────────────┐
│  ⚠️  Supprimer          │
│  votre compte ?         │
│                         │
│  Cette action est       │
│  irréversible.          │
│  Vos données seront     │
│  conservées 30 jours.   │
│                         │
│  Confirmez avec votre   │
│  code PIN :             │
│  [●][●][●][●]           │
│                         │
│  [Confirmer suppression]│
│  [Annuler]              │
└─────────────────────────┘
```

**Expert Odoo — API**
- Lecture profil : `search_read` sur `res.partner` par `uid`
- Mise à jour profil : `write` sur `res.partner` (nom, téléphone, adresse, localisation)
- Modification PIN : `write` sur `res.users`, champ `x_pin` (hashé)
- Adresses sauvegardées : `search_read` sur `res.partner` avec `parent_id`
- Localisation GPS : `write` sur `res.partner`, champs `x_latitude`, `x_longitude`
- Suppression compte : `write` sur `res.users`, champ `active = false` (suppression logique)
- Préférences langue : stocké localement (AsyncStorage React Native)

**QA — Critères d'acceptation**
- [ ] Informations personnelles affichées et modifiables (prénom, nom, téléphone)
- [ ] Modification du code PIN depuis le profil
- [ ] Gestion des adresses de livraison sauvegardées
- [ ] Mise à jour de la localisation GPS depuis le profil
- [ ] Changement de langue FR/AR fonctionnel et immédiat
- [ ] Préférences notifications modifiables
- [ ] Bouton suppression de compte visible et accessible
- [ ] Suppression compte : confirmation en deux étapes (popup + saisie PIN)
- [ ] Suppression logique : compte désactivé dans Odoo, données conservées
- [ ] Confirmation par SMS après suppression effective
- [ ] Déconnexion fonctionnelle et retour écran auth
- [ ] Affichage correct en FR et AR (RTL)

---

### F11 — Notifications Push

**Product Owner — User Story**
> En tant qu'utilisateur, je veux recevoir des notifications push aux moments clés de ma commande afin d'être informé sans avoir à ouvrir l'app.

**UX Designer**
```
Notifications déclenchées :
• ✅ "Commande #ECH-0042 confirmée !"
• 🔄 "Votre commande est en cours de préparation"
• 📦 "Votre commande est prête !"
• 🚗 "Votre livreur est en route"
• ✅ "Commande livrée — Bonne dégustation !"
```

**Expert Odoo — API**
- Déclencheur : changement de statut `sale.order` ou `stock.picking`
- Mécanisme : webhook Odoo → Firebase Cloud Messaging → app mobile
- Token Firebase : enregistré sur `res.partner` à la connexion (custom field `x_firebase_token`)

**QA — Critères d'acceptation**
- [ ] Notification reçue à chaque changement de statut commande
- [ ] Notification ouvre le suivi commande correspondant
- [ ] Notifications reçues même app fermée (background)
- [ ] Désactivation notifications possible depuis le profil
- [ ] Contenu notification disponible en FR et AR selon préférence utilisateur

---

### F00 — Vitrine Publique (avant inscription)

**Product Owner — User Story**
> En tant que visiteur non inscrit, je veux naviguer librement dans une sélection de produits avec les meilleurs prix afin de découvrir l'offre avant de créer mon compte.

**UX Designer — Wireframe**
```
Écran vitrine :
┌─────────────────────────┐
│ [Logo Echango Order]    │
│                         │
│ Nos meilleurs prix 🏷️  │
│                         │
│ ┌──────┐  ┌──────┐     │
│ │ img  │  │ img  │     │
│ │Pommes│  │Lait  │     │
│ │1.99€ │  │0.99€ │     │
│ │ [+]  │  │ [+]  │     │
│ └──────┘  └──────┘     │
│                         │
│ ┌──────┐  ┌──────┐     │
│ │ img  │  │ img  │     │
│ │Pain  │  │Huile │     │
│ │0.80€ │  │2.50€ │     │
│ │ [+]  │  │ [+]  │     │
│ └──────┘  └──────┘     │
│                         │
│ [S'inscrire pour        │
│  commander →]           │
└─────────────────────────┘

Popup au clic "Ajouter au panier" :
┌─────────────────────────┐
│                         │
│  🛒 Envie de commander ?│
│                         │
│  Créez votre compte     │
│  gratuitement pour      │
│  profiter de nos        │
│  meilleurs prix !       │
│                         │
│  [S'inscrire]           │
│  [Se connecter]         │
│  [Plus tard]            │
│                         │
└─────────────────────────┘
```
- Navigation libre dans la sélection de produits vitrine
- Bouton "Ajouter au panier" visible mais déclenche le popup
- Bouton fixe "S'inscrire pour commander" en bas de l'écran
- Sélection des produits configurable depuis Odoo back-office
- Disponible en FR et AR (RTL)

**Expert Odoo — API**
- Produits vitrine : `search_read` sur `product.template`, filter `x_vitrine_publique = true`
- Custom field à créer : `x_vitrine_publique` (booléen, configurable back-office)
- Aucune authentification requise pour cet appel API (endpoint public)
- Prix affiché : champ `list_price` standard

**QA — Critères d'acceptation**
- [ ] Vitrine affichée sans connexion ni inscription
- [ ] Navigation et scroll libres dans les produits vitrine
- [ ] Clic "Ajouter au panier" déclenche le popup inscription
- [ ] Popup propose "S'inscrire", "Se connecter" et "Plus tard"
- [ ] "Plus tard" ferme le popup et reste sur la vitrine
- [ ] "S'inscrire" et "Se connecter" redirigent vers F02
- [ ] Sélection produits mise à jour dynamiquement depuis Odoo
- [ ] Produit sans stock toujours visible mais badge "Indisponible"
- [ ] Affichage correct en FR et AR (RTL)

---

### F12 — Partage Produit (Deep Link)

**Product Owner — User Story**
> En tant qu'utilisateur, je veux partager un produit avec mes proches via un lien afin qu'ils puissent le voir directement dans l'app ou être redirigés vers le store pour l'installer.

**UX Designer — Wireframe**
```
Bouton partage sur fiche produit :
┌─────────────────────────┐
│ ←               [↗️ 🔗] │  ← bouton partage
│                         │
│ ┌─────────────────────┐ │
│ │      [Photo]        │ │
│ └─────────────────────┘ │
│                         │
│ Huile d'olive extra     │
│ 2.50€ / litre           │
│                         │
│ [Ajouter au panier]     │
└─────────────────────────┘

Sheet de partage natif (iOS/Android) :
┌─────────────────────────┐
│ Partager ce produit     │
│                         │
│ [WhatsApp] [SMS]        │
│ [Email]    [Copier lien]│
│                         │
│ "Découvre ce produit    │
│  sur Echango Order :    │
│  Huile d'olive 2.50€   │
│  👉 https://echo.app/  │
│     produit/123"        │
└─────────────────────────┘

Comportement du lien reçu :
┌─────────────────────────┐
│  App installée ?        │
│       ↓                 │
│  OUI → Ouvre l'app      │
│         directement sur │
│         la fiche produit│
│       ↓                 │
│  NON → Redirige vers    │
│         App Store ou    │
│         Play Store      │
│         avec deep link  │
│         mémorisé        │
└─────────────────────────┘
```
- Bouton partage disponible sur chaque fiche produit
- Partage via le sheet natif iOS/Android (WhatsApp, SMS, Email, Copier lien)
- Lien contient : nom produit + prix + deep link vers l'app
- Si app installée → ouvre directement la fiche produit
- Si app non installée → redirige vers App Store / Play Store
- Après installation → ouvre automatiquement la fiche produit partagée (deferred deep link)
- Fonctionne depuis la vitrine publique ET depuis l'app connectée

**Expert Odoo — API**
- Données produit pour le lien : `search_read` sur `product.template` par id
- Champs : `name`, `list_price`, `image_1920`
- Endpoint public nécessaire : accès fiche produit sans authentification

**Infrastructure Deep Link**
- Technologie : **Branch.io** ou **Firebase Dynamic Links** (gratuit jusqu'à large volume)
- Format lien : `https://echanorder.app/produit/{id}`
- Universal Links (iOS) + App Links (Android) configurés
- Deferred deep link : mémorise le produit cible même si l'app n'est pas encore installée

**QA — Critères d'acceptation**
- [ ] Bouton partage visible sur chaque fiche produit (vitrine et app connectée)
- [ ] Sheet de partage natif s'ouvre avec le bon message et lien
- [ ] Lien contient nom produit, prix et URL deep link
- [ ] Clic lien sur mobile avec app installée → ouvre fiche produit dans l'app
- [ ] Clic lien sur mobile sans app → redirige vers App Store (iOS) ou Play Store (Android)
- [ ] Après installation depuis le lien → ouvre automatiquement la fiche produit
- [ ] Clic lien depuis desktop → affiche page web de téléchargement de l'app
- [ ] Fonctionnel depuis la vitrine publique (sans compte)
- [ ] Fonctionnel depuis l'app connectée
- [ ] Affichage correct en FR et AR (RTL)

---

---

### F13 — Pages Légales

**Product Owner — User Story**
> En tant qu'utilisateur, je veux accéder aux CGU, à la politique de confidentialité et aux mentions légales afin de connaître mes droits et les conditions d'utilisation de l'app.

**UX Designer — Wireframe**
```
┌─────────────────────────┐
│ ← Conditions d'util.   │
│                         │
│ [Texte CGU complet      │
│  scrollable]            │
│                         │
│ Version 1.0             │
│ Mise à jour : 07/2026   │
└─────────────────────────┘
```
- Pages accessibles depuis le profil ET depuis l'écran d'inscription
- Contenu scrollable, texte lisible
- Date de dernière mise à jour visible
- Pages disponibles en FR et AR

**Pages requises (obligatoires Apple & Google) :**
- **CGU** — Conditions Générales d'Utilisation
- **Politique de confidentialité / RGPD** — collecte et usage des données
- **Mentions légales** — informations société
- **Politique de cookies** — si applicable

**Expert Odoo — API**
- Aucun appel API — contenu statique intégré dans l'app ou chargé depuis une URL configurable

**QA — Critères d'acceptation**
- [ ] CGU accessible depuis l'inscription et depuis le profil
- [ ] Politique de confidentialité accessible depuis l'inscription et le profil
- [ ] Mentions légales accessibles depuis "À propos"
- [ ] Contenu scrollable sans troncature
- [ ] Date de mise à jour visible sur chaque page
- [ ] Pages disponibles en FR et AR (RTL)
- [ ] Lien CGU dans l'inscription ouvre la bonne page

---

### F14 — Gestion des Permissions & États Système

**Product Owner — User Story**
> En tant qu'utilisateur, je veux être informé clairement pourquoi l'app demande certaines permissions et voir un message propre si le service est indisponible.

**UX Designer — Wireframe**
```
Demande permission localisation :
┌─────────────────────────┐
│  📍 Votre localisation  │
│                         │
│  Echango Order utilise  │
│  votre position pour    │
│  pré-remplir votre      │
│  adresse de livraison.  │
│                         │
│  [Autoriser]            │
│  [Pas maintenant]       │
└─────────────────────────┘

Demande permission notifications :
┌─────────────────────────┐
│  🔔 Notifications       │
│                         │
│  Recevez des alertes    │
│  sur l'avancement de    │
│  vos commandes.         │
│                         │
│  [Autoriser]            │
│  [Pas maintenant]       │
└─────────────────────────┘

Écran maintenance :
┌─────────────────────────┐
│                         │
│       🔧                │
│                         │
│  App en maintenance     │
│                         │
│  Nous revenons très     │
│  bientôt !              │
│                         │
│  [Réessayer]            │
└─────────────────────────┘

Écran "À propos" :
┌─────────────────────────┐
│ ← À propos              │
│                         │
│  [Logo]                 │
│  Echango Order          │
│  Version 1.0.0          │
│                         │
│  Contact support :      │
│  support@echango.app    │
│                         │
│  📄 CGU            ›    │
│  🔒 Confidentialité ›   │
│  📋 Mentions légales ›  │
└─────────────────────────┘
```

**Expert Odoo — API**
- Endpoint de santé : `GET /web/health` → vérifie si Odoo est disponible
- Si indisponible → affichage écran maintenance automatique

**QA — Critères d'acceptation**
- [ ] Explication affichée AVANT la demande de permission système
- [ ] Permission localisation demandée uniquement si l'utilisateur clique le bouton GPS
- [ ] Permission notifications demandée après la première commande confirmée
- [ ] Refus de permission géré sans bloquer l'utilisation de l'app
- [ ] Écran maintenance affiché si Odoo inaccessible
- [ ] Bouton "Réessayer" sur l'écran maintenance
- [ ] Écran "À propos" avec version, contact et liens légaux
- [ ] Numéro de version visible et à jour
- [ ] Affichage correct en FR et AR (RTL)

---

### F15 — Code Promo

**Product Owner — User Story**
> En tant qu'utilisateur, je veux saisir un code promo lors du checkout afin de bénéficier d'une réduction sur ma commande.

**UX Designer — Wireframe**
```
Dans le récapitulatif checkout :
┌─────────────────────────┐
│ ← Récapitulatif         │
│                         │
│ 📦 3 articles           │
│                         │
│ ┌─────────────────────┐ │
│ │ Code promo          │ │
│ │ [______________] [OK]│ │
│ └─────────────────────┘ │
│                         │
│ Sous-total :   8.20€    │
│ Réduction :   -1.00€   │
│ Livraison :    2.00€    │
│ **Total :      9.20€**  │
│                         │
│ [Confirmer la commande] │
└─────────────────────────┘

Code valide :
┌─────────────────────────┐
│ ✅ Code "BIENVENUE"     │
│    -1.00€ appliqué !    │
└─────────────────────────┘

Code invalide :
┌─────────────────────────┐
│ ❌ Code invalide ou     │
│    expiré               │
└─────────────────────────┘
```
- Champ code promo dans le récapitulatif checkout
- Validation immédiate à la saisie
- Affichage de la réduction appliquée
- Message d'erreur si code invalide ou expiré
- Un seul code promo par commande

**Expert Odoo — API**
- Validation code promo : `search_read` sur `sale.coupon.program` ou module OCA équivalent
- Application réduction : `write` sur `sale.order`, champ `coupon_code`
- Champs : code, montant réduction, date expiration, nombre utilisations restantes

**QA — Critères d'acceptation**
- [ ] Champ code promo visible dans le récapitulatif checkout
- [ ] Code valide → réduction affichée et déduite du total
- [ ] Code invalide → message d'erreur clair
- [ ] Code expiré → message d'erreur spécifique
- [ ] Code déjà utilisé → message d'erreur spécifique
- [ ] Un seul code applicable par commande
- [ ] Réduction visible sur le récapitulatif final et la confirmation
- [ ] Affichage correct en FR et AR (RTL)

---

### F16 — Annulation Commande

**Product Owner — User Story**
> En tant qu'utilisateur, je veux pouvoir annuler ma commande dans un délai défini afin de corriger une erreur ou changer d'avis après avoir commandé.

**UX Designer — Wireframe**
```
Depuis le suivi commande :
┌─────────────────────────┐
│ ← Commande #ECH-0042    │
│                         │
│ ✅ Commande confirmée   │
│ ○  En préparation       │
│ ○  Prête                │
│ ○  En livraison         │
│ ○  Livrée               │
│                         │
│ [Annuler la commande]   │  ← visible seulement si annulation possible
└─────────────────────────┘

Popup confirmation annulation :
┌─────────────────────────┐
│  ⚠️  Annuler la         │
│  commande ?             │
│                         │
│  Cette action est       │
│  irréversible.          │
│                         │
│  [Confirmer annulation] │
│  [Garder ma commande]   │
└─────────────────────────┘

Après annulation :
┌─────────────────────────┐
│  ✅ Commande annulée    │
│                         │
│  Votre commande         │
│  #ECH-0042 a bien       │
│  été annulée.           │
│                         │
│  [Retour accueil]       │
└─────────────────────────┘
```
- Annulation possible uniquement si statut = "Confirmée" (avant préparation)
- Bouton annulation masqué une fois la préparation commencée
- Confirmation en deux étapes (popup)
- Notification push confirmant l'annulation

**Expert Odoo — API**
- Annulation : `write` sur `sale.order`, champ `state = cancel`
- Vérification statut avant annulation : `search_read` sur `sale.order`, champ `state`
- Notification push annulation : webhook Odoo → Firebase

**QA — Critères d'acceptation**
- [ ] Bouton annulation visible uniquement si statut "Confirmée"
- [ ] Bouton annulation masqué si préparation commencée
- [ ] Popup de confirmation avant annulation effective
- [ ] Commande marquée "Annulée" dans Odoo après confirmation
- [ ] Notification push envoyée au client après annulation
- [ ] Historique affiche le statut "Annulée" correctement
- [ ] Affichage correct en FR et AR (RTL)

---

### F17 — Gestion Substitution Produit

**Product Owner — User Story**
> En tant qu'utilisateur, je veux être informé si un produit de ma commande est indisponible à la préparation et choisir une alternative afin de ne pas avoir de mauvaise surprise à la livraison.

**UX Designer — Wireframe**
```
Notification substitution :
┌─────────────────────────┐
│ 🔔 Produit indisponible │
│                         │
│ "Lait entier 1L" n'est  │
│ plus disponible.        │
│                         │
│ Suggestion :            │
│ ┌─────────────────────┐ │
│ │img│ Lait demi-écrémé│ │
│ │   │ 1L — 1.10€      │ │
│ │   │ [Accepter]      │ │
│ └─────────────────────┘ │
│                         │
│ [Refuser — Supprimer    │
│  cet article]           │
└─────────────────────────┘
```
- Notification push envoyée si un produit est indisponible
- Le client accepte la substitution ou refuse (article supprimé)
- Délai de réponse : 30 minutes, sinon substitution automatique appliquée
- Total commande mis à jour selon le choix

**Expert Odoo — API**
- Signalement rupture : géré par le préparateur via Odoo back-office (Phase 1 manuelle)
- Substitution : custom field `x_substitution_produit` sur `sale.order.line`
- Notification client : webhook Odoo → Firebase avec détail produit substitué
- Acceptation/refus client : `write` sur `sale.order.line`

**QA — Critères d'acceptation**
- [ ] Notification push reçue si produit indisponible
- [ ] Écran substitution affiche produit original et suggestion
- [ ] Client peut accepter ou refuser la substitution
- [ ] Refus → article supprimé de la commande, total mis à jour
- [ ] Acceptation → commande mise à jour avec le produit substitué
- [ ] Si pas de réponse dans 30 min → substitution automatique appliquée
- [ ] Notification de confirmation après choix du client
- [ ] Affichage correct en FR et AR (RTL)


---

## 4. Exigences Transversales

### 4.1 Performance
- Temps de chargement page d'accueil : < 2 secondes
- Temps de réponse API : < 1 seconde
- Taille app : < 50 MB

### 4.2 Accessibilité
- Taille de police lisible sur petits écrans (min 14px)
- Contraste suffisant pour lecture en plein soleil
- Boutons suffisamment larges (min 44px de hauteur)

### 4.3 Internationalisation
- Toutes les chaînes de caractères externalisées dans fichiers de traduction
- Layout miroir complet en arabe (RTL)
- Formats de date et heure adaptés par langue

### 4.4 Gestion des erreurs
- Message d'erreur clair si pas de connexion internet
- Retry automatique sur les appels API en échec
- Aucun crash silencieux — toute erreur est loguée

### 4.5 Sécurité
- **HTTPS / TLS 1.3 obligatoire** sur toutes les communications app ↔ Odoo — aucune requête HTTP en clair
- **Stockage PIN sécurisé sur device** — iOS Keychain / Android Keystore uniquement, jamais en clair
- **Token de session avec expiration** — session invalide après 24h d'inactivité, re-authentification PIN requise
- **Délai progressif tentatives PIN** — 1s après 1er échec, 2s après 2e, 4s après 3e, 8s après 4e, blocage après 5e
- **Données API filtrées** — les endpoints Odoo ne retournent que les champs nécessaires, jamais les données d'autres utilisateurs
- **Rate limiting** sur tous les endpoints publics (vitrine, deep links) — protection scraping et abus

---

## 5. Hors Périmètre Phase 1

**Reporté Phase 2 :**
- Filtres avancés catalogue (prix croissant/décroissant, disponibilité)
- Badge promo / nouveau / stock faible sur les produits
- Minimum de commande + frais livraison variables et affichés dès le choix du mode
- Estimation temps livraison sur confirmation commande
- Pagination avancée des APIs Odoo
- Système de favoris et listes de courses
- Recommandations produits
- Support client intégré (chat)
- Notation et avis produits
- Politique annulation précise (délai en minutes configurable)
- Comportement code promo après annulation commande
- Comportement commande vide après refus toutes substitutions
- Tests accessibilité VoiceOver (iOS) et TalkBack (Android)

**Reporté Phase 3+ :**
- Paiement en ligne (carte, Apple Pay, Google Pay)
- Programme fidélité
- Tracking GPS transporteur temps réel
- App Préparateurs
- App Transporteur Echango Delivery
- Intégration Fleetbase

---

## 6. Points de Vigilance par Agent

### Product Owner
- Valider les statuts de commande Odoo avec l'Expert Odoo avant le développement
- Confirmer le wording FR et AR de chaque notification push
- Définir le comportement exact des créneaux complets ou expirés
- Valider le parcours invité : que se passe-t-il si l'invité veut suivre sa commande ?
- Définir le message de partage produit en FR et AR
- Définir la page de destination desktop pour les deep links
- Valider le contenu CGU et politique de confidentialité avec un juriste avant soumission stores
- Définir la durée de conservation des données après suppression de compte (RGPD)
- Définir le délai d'annulation commande autorisé (ex: 5 minutes après confirmation)
- Définir la politique de substitution : quels produits peuvent être substitués ?
- Définir le délai de réponse client pour accepter/refuser une substitution
- Définir les règles des codes promo (usage unique, multi-usage, date expiration)
- Définir les zones de livraison et les codes postaux couverts
- Définir le délai d'expiration de session (recommandé : 24h)

### UX Designer
- Tester chaque écran en arabe avant validation — le RTL impacte tous les composants
- Valider les wireframes sur petits écrans (iPhone SE, Android entrée de gamme)
- Définir les états vides pour chaque écran (panier vide, aucune commande, aucun résultat recherche)
- Prévoir les états de chargement (skeleton screens) pour chaque liste
- Concevoir le popup inscription de façon engageante mais non intrusive
- Valider l'affichage du bouton partage sur petits écrans sans masquer le contenu
- Concevoir les écrans de permission de façon claire et rassurante
- Valider l'écran de maintenance sur les deux langues
- Concevoir l'écran de substitution produit de façon claire et rassurante
- Définir l'état visuel du bouton annulation (couleur danger, confirmation obligatoire)
- Valider l'affichage du code promo sur petits écrans
- Concevoir le message hors zone de livraison de façon non frustrante
- Valider l'affichage du bouton reorder sans surcharger la liste commandes

### Expert Odoo
- Confirmer la disponibilité de tous les endpoints listés sur Odoo 19
- Valider les custom fields nécessaires : `x_reception_mode`, `x_creneau`, `x_firebase_token`, `x_vitrine_publique`, `x_pin` (hashé), `x_langue`, `x_latitude`, `x_longitude`, `x_adresse_favorite`
- Valider que l'endpoint produit vitrine est accessible sans authentification Odoo
- Valider l'accès public à la fiche produit pour les deep links
- Confirmer le mécanisme de déclenchement webhook pour Firebase
- Tester les APIs en environnement Odoo 19 avant le démarrage du dev mobile
- Développer l'endpoint custom auth téléphone/PIN (non natif Odoo 19)
- Implémenter le hash PIN avec bcrypt ou équivalent côté Odoo
- Mettre en place le rate limiting sur l'endpoint vitrine publique (protection scraping)
- Bloquer le compte après 5 tentatives PIN échouées
- Valider le module coupon/promo compatible Odoo 19
- Implémenter délai progressif tentatives PIN (1s/2s/4s/8s/blocage)
- Configurer expiration session 24h côté Odoo
- Valider filtrage strict des champs retournés par les APIs (pas de surexposition données)
- Créer le modèle `x_delivery_zone` pour la gestion des zones de livraison

### QA Engineer
- Préparer les jeux de données de test : produits, catégories, créneaux dans Odoo
- Tester sur minimum 4 appareils : iOS récent, iOS ancien, Android haut de gamme, Android entrée de gamme
- Tester les deux langues sur chaque écran et chaque fonctionnalité
- Tester les cas limites : panier vide, stock épuisé, créneau complet, pas de connexion
- Tester les deep links sur iOS et Android (app installée, non installée, après installation)
- Tester le popup vitrine sur les deux langues
- Vérifier que les produits vitrine se mettent à jour après modification dans Odoo
- Tester le flux complet suppression de compte (désactivation Odoo + confirmation SMS)
- Tester les écrans légaux sur les deux langues
- Tester l'écran maintenance (couper Odoo et vérifier l'affichage)
- Tester les permissions refusées sur iOS et Android
- Tester blocage PIN après 5 tentatives échouées
- Tester injection SQL sur les champs de recherche et code promo
- Tester accès aux données d'un autre utilisateur (isolation)
- Tester comportement hors ligne pendant le checkout
- Tester notifications background iOS (comportement différent d'Android)
- Checklist régression bilingue FR/AR à chaque release
- Tester expiration session pendant le checkout (re-auth PIN demandée)
- Tester adresse hors zone de livraison avec proposition retrait en magasin
- Tester reorder avec produits partiellement indisponibles
- Tester reorder avec tous les produits indisponibles
- Tester code promo sur commande reorder
- Vérifier que le PIN n'est jamais stocké en clair sur le device
- Vérifier que toutes les requêtes utilisent HTTPS

---

*Document v1.5 — validé par 3 passes d'agents — prêt pour le développement.*
