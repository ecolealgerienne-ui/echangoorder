from odoo import http
from odoo.exceptions import UserError
from odoo.http import request


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
