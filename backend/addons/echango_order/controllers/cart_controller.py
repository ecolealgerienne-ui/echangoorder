from odoo import http
from odoo.exceptions import UserError
from odoo.http import request

from .session_utils import require_fresh_session


class EchangoCartController(http.Controller):
    """Panier (F06) = devis (`sale.order` à l'état brouillon) du client
    connecté, un par client, retrouvé/créé à la volée — pas un état
    "panier" séparé : on utilise directement le modèle standard, comme
    prévu par les specs Expert Odoo (create/write/unlink sur
    sale.order/sale.order.line).

    Odoo restreint volontairement le groupe portail à un accès **lecture
    seule** sur ces deux modèles (`addons/sale/security/ir.model.access.csv`
    : `access_sale_order_portal`/`access_sale_order_line_portal`, tous les
    deux `1,0,0,0`) — ce n'est pas un oubli de configuration comme pour le
    catalogue (F03/F04/F05), c'est une limite de sécurité déjà voulue par
    Odoo pour empêcher un client de manipuler directement des documents de
    vente (prix, quantités, lignes arbitraires) via l'ORM. On passe donc
    par ce contrôleur, qui applique lui-même les vérifications
    (propriétaire du devis, produit vendable) avant d'agir en sudo(),
    plutôt que d'élargir les droits ORM bruts du portail.
    """

    def _cart_order(self, create=False):
        # `sent` inclus (F08, décision produit 2026-07 — voir CLAUDE.md §
        # Statuts de commande) : une commande déjà "confirmée" côté client
        # mais pas encore prise en charge par un opérateur (`action_
        # confirm()` toujours pas appelé, voir `models/sale_order.py`)
        # reste la commande courante — le client peut continuer à y
        # ajouter des produits depuis le catalogue, pas seulement pendant
        # qu'elle est en brouillon. Une fois prise en charge (`state ==
        # 'sale'`), elle sort de ce domaine et un nouvel achat démarre un
        # nouveau panier `draft`, comme avant.
        partner = request.env.user.partner_id
        order = request.env["sale.order"].sudo().search(
            [("partner_id", "=", partner.id), ("state", "in", ("draft", "sent"))],
            order="id desc", limit=1,
        )
        if not order and create:
            order = request.env["sale.order"].sudo().create({"partner_id": partner.id})
        return order

    def _owned_line(self, line_id):
        if not line_id:
            return None
        partner = request.env.user.partner_id
        return request.env["sale.order.line"].sudo().search([
            ("id", "=", line_id),
            ("order_id.partner_id", "=", partner.id),
            ("order_id.state", "in", ("draft", "sent")),
        ], limit=1)

    def _cart_payload(self, order):
        # Qualité clients — remonté ici (et pas seulement à la confirmation
        # finale) pour que l'app puisse avertir/bloquer "Valider mon
        # panier" dès l'écran Panier plutôt qu'au bout du tunnel checkout.
        # La vérification qui compte réellement reste côté serveur, au
        # moment de `/echango/checkout/confirm`.
        verification_state = request.env.user.partner_id.x_verification_state
        if not order:
            return {
                "order_id": None, "lines": [], "amount_subtotal": 0.0, "amount_total": 0.0, "discount": 0.0,
                "verification_state": verification_state,
            }
        # Promotions automatiques (badge "Promo") : `_update_programs_and_rewards`
        # seul (module standard `sale_loyalty`) recalcule l'éligibilité mais
        # n'ajoute PAS la ligne de remise — confirmé en reproduisant le
        # comportement du bouton "Récompense" de l'interface Ventes
        # standard (nécessaire même là, testé par l'utilisateur directement
        # dans Odoo), qui appelle `action_open_reward_wizard()` : celui-ci
        # fait `_update_programs_and_rewards()` PUIS `_apply_program_reward()`
        # sur l'unique récompense réclamable s'il n'y en a qu'une (sinon
        # renvoie une action d'assistant de choix, ignorée ici — même
        # simplification déjà actée pour F15 : un programme correctement
        # configuré n'a qu'une récompense, pas d'écran de choix multiple).
        # Rappelé ici (plutôt que dans chaque route add/update/remove) pour
        # couvrir aussi `/echango/cart` (simple consultation).
        #
        # `action_open_reward_wizard()` est en réalité la méthode du bouton
        # "Récompense" de l'interface Ventes standard — pensée pour un humain
        # qui clique en s'attendant à une récompense : si l'ordre n'est
        # ELIGIBLE À AUCUNE récompense au moment de l'appel (cas normal la
        # plupart du temps — pas de code promo actif, pas de promotion
        # automatique applicable), elle lève un `UserError` ("Il n'y a
        # aucune remise à appliquer") au lieu de ne rien faire. Non catché,
        # ça annule toute la requête en cours (rollback Odoo, y compris un
        # retrait de ligne déjà effectué juste avant) et remonte comme une
        # erreur serveur générique côté app — reproduit en réel (2026-07-20)
        # en retirant une ligne dont la récompense associée (`loyalty.card`)
        # disparaissait avec elle : le rappel de cette méthode juste après,
        # sur un panier qui ne remplit plus aucune condition de récompense,
        # déclenchait ce `UserError`. Capturé ici : "rien à appliquer" est
        # un résultat normal d'un recalcul automatique, pas une erreur.
        try:
            order.sudo().action_open_reward_wizard()
        except UserError:
            pass
        lines = []
        product_lines = order.order_line.filtered(lambda l: not l.is_reward_line)
        # F15 — les lignes de récompense (code promo appliqué, module
        # standard `loyalty`/`sale_loyalty`) sont exclues de la liste
        # produit : elles n'ont pas de +/- quantité ni de bouton supprimer
        # côté app, la réduction est affichée séparément (`discount`,
        # `order.reward_amount` — champ standard, déjà négatif).
        for line in product_lines:
            product = line.product_id
            image = product.image_128
            lines.append({
                "line_id": line.id,
                "product_id": product.product_tmpl_id.id,
                "name": product.display_name,
                "image_128": image.decode() if image else None,
                "uom": product.uom_id.name,
                "qty": line.product_uom_qty,
                "unit_price": line.price_unit,
                "subtotal": line.price_subtotal,
            })
        return {
            "order_id": order.id,
            "lines": lines,
            # `order.amount_untaxed` inclut déjà la ligne de récompense
            # (négative) : ce n'est donc pas un "sous-total brut" (demande
            # utilisateur), juste `amount_total` sans les taxes. Le vrai
            # sous-total brut est la somme des lignes produit seules, hors
            # récompense — `amount_total` reste la source de vérité pour le
            # montant final payé (déjà net de la remise).
            "amount_subtotal": sum(product_lines.mapped("price_subtotal")),
            "amount_total": order.amount_total,
            "discount": order.reward_amount,
            "verification_state": verification_state,
        }

    @http.route("/echango/cart", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def get_cart(self, **kw):
        return self._cart_payload(self._cart_order())

    @http.route("/echango/cart/add", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def add(self, product_id=None, qty=1, variant_id=None, **kw):
        template = request.env["product.template"].sudo().search(
            [("id", "=", product_id), ("sale_ok", "=", True)], limit=1,
        )
        if not template:
            return {"error": "cart.product_unavailable"}

        # F05 — sélection de variante (couleur/taille...) : `variant_id`
        # transmis une fois la combinaison résolue côté app (voir
        # `catalog_controller.py.variants()`) — jusqu'ici toujours ignoré,
        # l'ajout prenait systématiquement `template.product_variant_id`
        # (la variante par défaut Odoo), quelle que soit la sélection du
        # client. Vérifié explicitement qu'il appartient bien à ce template
        # (pas de confiance aveugle dans un id fourni par le client).
        if variant_id:
            variant = request.env["product.product"].sudo().search(
                [("id", "=", variant_id), ("product_tmpl_id", "=", template.id)], limit=1,
            )
            if not variant:
                return {"error": "cart.product_unavailable"}
        else:
            variant = template.product_variant_id

        # Vérification stock côté serveur (pas seulement client) : le
        # bouton désactivé côté app ne suffit pas, un appel direct à cet
        # endpoint doit aussi être bloqué. Stock de la variante précise
        # (`product.product.qty_available`) plutôt que l'agrégat du
        # template (toutes variantes confondues) — une variante peut être
        # en rupture pendant qu'une autre du même produit est disponible.
        if variant.qty_available <= 0:
            return {"error": "cart.product_unavailable"}
        qty = max(1, qty or 1)

        order = self._cart_order(create=True)
        line = order.order_line.filtered(lambda l: l.product_id == variant)
        if line:
            line.sudo().write({"product_uom_qty": line.product_uom_qty + qty})
        else:
            # `price_unit` explicitement forcé au prix catalogue
            # (`list_price`, le même champ que l'Accueil/Catalogue/Recherche
            # affichent) plutôt que de laisser Odoo le calculer via la liste
            # de prix du client (`_compute_price_unit`, standard) — décision
            # utilisateur suite à un écart de prix constaté entre catalogue
            # et panier, causé par une liste de prix/devise différente
            # assignée à certains clients. Plus simple qu'une liste de prix
            # unique à maintenir, et garantit que catalogue et panier
            # affichent toujours exactement le même montant. Pour une
            # variante précise, `variant.lst_price` (prix de base + éventuel
            # supplément d'attribut, `price_extra`) est la bonne source —
            # `template.list_price` reste le repli pour la variante par
            # défaut, comportement inchangé pour tout produit sans variante.
            request.env["sale.order.line"].sudo().create({
                "order_id": order.id,
                "product_id": variant.id,
                "product_uom_qty": qty,
                "price_unit": variant.lst_price if variant_id else template.list_price,
            })
        return self._cart_payload(order)

    @http.route("/echango/cart/update", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def update(self, line_id=None, qty=1, **kw):
        line = self._owned_line(line_id)
        if not line:
            return {"error": "not_found"}
        line.sudo().write({"product_uom_qty": max(1, qty or 1)})
        return self._cart_payload(line.order_id)

    @http.route("/echango/cart/remove", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def remove(self, line_id=None, **kw):
        line = self._owned_line(line_id)
        if not line:
            return {"error": "not_found"}
        order = line.order_id
        line.sudo().unlink()
        return self._cart_payload(order)

    @http.route("/echango/cart/reorder", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def reorder(self, order_id=None, **kw):
        """F09 — recopie les lignes d'une commande passée dans le panier en
        cours, en excluant les produits qui ne sont plus vendables/en stock
        (specs QA : "produits indisponibles exclus automatiquement, avec
        message informatif")."""
        partner = request.env.user.partner_id
        source = request.env["sale.order"].sudo().search([
            ("id", "=", order_id), ("partner_id", "=", partner.id),
        ], limit=1)
        if not source:
            return {"error": "not_found"}

        cart = self._cart_order(create=True)
        unavailable = []
        for line in source.order_line:
            variant = line.product_id
            template = variant.product_tmpl_id
            if not template.sale_ok or template.qty_available <= 0:
                unavailable.append(line.name)
                continue
            existing = cart.order_line.filtered(lambda l: l.product_id == variant)
            if existing:
                existing.sudo().write({"product_uom_qty": existing.product_uom_qty + line.product_uom_qty})
            else:
                # Même logique que add() : prix catalogue forcé, pas de
                # recalcul via liste de prix.
                request.env["sale.order.line"].sudo().create({
                    "order_id": cart.id,
                    "product_id": variant.id,
                    "product_uom_qty": line.product_uom_qty,
                    "price_unit": template.list_price,
                })

        payload = self._cart_payload(cart)
        payload["unavailable"] = unavailable
        return payload
