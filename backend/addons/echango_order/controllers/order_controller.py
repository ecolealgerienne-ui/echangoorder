from odoo import http
from odoo.exceptions import UserError
from odoo.http import request

from .session_utils import require_fresh_session


class EchangoOrderController(http.Controller):
    """F16/F17 — actions sur une commande déjà confirmée (annulation,
    substitution). `sale.order`/`sale.order.line` restent en lecture seule
    pour le portail (voir F06/F09) : toute écriture passe ici, en `sudo()`,
    avec vérification explicite de propriété (`partner_id`).
    """

    def _owned_order(self, order_id):
        partner = request.env.user.partner_id
        return request.env["sale.order"].sudo().search([
            ("id", "=", order_id), ("partner_id", "=", partner.id),
        ], limit=1)

    @http.route("/echango/order/cancel", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def cancel(self, order_id=None, **kw):
        order = self._owned_order(order_id)
        if not order:
            return {"error": "not_found"}
        # F16 — annulation possible uniquement tant que la commande est
        # "Confirmée" et pas encore en préparation (specs QA). Pas de
        # suivi stock.picking synchronisé (F08 différé) : `state == 'sale'`
        # est le seul proxy disponible actuellement pour "pas encore en
        # préparation" — voir status-V1.md, point de vigilance sur le
        # délai d'annulation exact.
        if order.state != "sale":
            return {"error": "order.cannot_cancel"}
        try:
            order.sudo().action_cancel()
        except UserError:
            return {"error": "order.cannot_cancel"}
        return {"success": True}

    def _owned_line(self, line_id):
        partner = request.env.user.partner_id
        return request.env["sale.order.line"].sudo().search([
            ("id", "=", line_id), ("order_id.partner_id", "=", partner.id),
        ], limit=1)

    @http.route("/echango/order/substitution", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def get_substitution(self, order_id=None, **kw):
        # F17 — le signalement de rupture + la suggestion sont saisis
        # manuellement par le préparateur en back-office (`x_substitution_
        # produit` sur la ligne, voir `views/sale_order_views.xml`) : côté
        # app, on se contente de lire s'il y en a une en attente pour cette
        # commande. `product.product` n'étant pas exposé au portail (voir
        # CLAUDE.md § Sécurité / F04), la résolution du nom/prix se fait ici
        # en `sudo()`, pas via un `search_read` direct côté client.
        order = self._owned_order(order_id)
        if not order:
            return {"error": "not_found"}
        line = order.order_line.filtered(lambda l: l.x_substitution_produit)[:1]
        if not line:
            return {"pending": False}
        substitute = line.x_substitution_produit
        return {
            "pending": True,
            "line_id": line.id,
            "original_name": line.product_id.display_name,
            "substitute_name": substitute.display_name,
            "substitute_price": substitute.lst_price,
        }

    @http.route("/echango/order/substitution/accept", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def accept_substitution(self, line_id=None, **kw):
        line = self._owned_line(line_id)
        if not line or not line.x_substitution_produit:
            return {"error": "not_found"}
        # Remplace le produit de la ligne — price_unit/name sont des champs
        # calculés stockés qui se recalculent automatiquement (dépendent de
        # product_id, vérifié contre le code source Odoo 19).
        line.sudo().write({
            "product_id": line.x_substitution_produit.id,
            "x_substitution_produit": False,
        })
        return {"success": True}

    @http.route("/echango/order/substitution/refuse", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def refuse_substitution(self, line_id=None, **kw):
        line = self._owned_line(line_id)
        if not line or not line.x_substitution_produit:
            return {"error": "not_found"}
        line.sudo().unlink()
        return {"success": True}
