from odoo import http
from odoo.http import request


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
        partner = request.env.user.partner_id
        order = request.env["sale.order"].sudo().search(
            [("partner_id", "=", partner.id), ("state", "=", "draft")],
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
            ("order_id.state", "=", "draft"),
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
        order.sudo().action_open_reward_wizard()
        lines = []
        # F15 — les lignes de récompense (code promo appliqué, module
        # standard `loyalty`/`sale_loyalty`) sont exclues de la liste
        # produit : elles n'ont pas de +/- quantité ni de bouton supprimer
        # côté app, la réduction est affichée séparément (`discount`,
        # `order.reward_amount` — champ standard, déjà négatif).
        for line in order.order_line.filtered(lambda l: not l.is_reward_line):
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
            "amount_subtotal": order.amount_untaxed,
            "amount_total": order.amount_total,
            "discount": order.reward_amount,
            "verification_state": verification_state,
        }

    @http.route("/echango/cart", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def get_cart(self, **kw):
        return self._cart_payload(self._cart_order())

    @http.route("/echango/cart/add", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def add(self, product_id=None, qty=1, **kw):
        template = request.env["product.template"].sudo().search(
            [("id", "=", product_id), ("sale_ok", "=", True)], limit=1,
        )
        # Vérification stock côté serveur (pas seulement client) : le
        # bouton désactivé côté app ne suffit pas, un appel direct à cet
        # endpoint doit aussi être bloqué.
        if not template or template.qty_available <= 0:
            return {"error": "cart.product_unavailable"}
        qty = max(1, qty or 1)

        order = self._cart_order(create=True)
        variant = template.product_variant_id
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
            # affichent toujours exactement le même montant.
            request.env["sale.order.line"].sudo().create({
                "order_id": order.id,
                "product_id": variant.id,
                "product_uom_qty": qty,
                "price_unit": template.list_price,
            })
        return self._cart_payload(order)

    @http.route("/echango/cart/update", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def update(self, line_id=None, qty=1, **kw):
        line = self._owned_line(line_id)
        if not line:
            return {"error": "not_found"}
        line.sudo().write({"product_uom_qty": max(1, qty or 1)})
        return self._cart_payload(line.order_id)

    @http.route("/echango/cart/remove", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def remove(self, line_id=None, **kw):
        line = self._owned_line(line_id)
        if not line:
            return {"error": "not_found"}
        order = line.order_id
        line.sudo().unlink()
        return self._cart_payload(order)

    @http.route("/echango/cart/reorder", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
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
