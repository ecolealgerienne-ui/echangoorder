from odoo import http
from odoo.exceptions import UserError
from odoo.http import request

from .session_utils import require_fresh_session


class EchangoOrderController(http.Controller):
    """F16 — actions sur une commande déjà confirmée (annulation).
    `sale.order`/`sale.order.line` restent en lecture seule pour le portail
    (voir F06/F09) : toute écriture passe ici, en `sudo()`, avec
    vérification explicite de propriété (`partner_id`).

    F17 (substitution post-confirmation par le préparateur) supprimé —
    décision produit 2026-07, remplacé par la résolution côté client au
    moment de `/echango/checkout/confirm` (voir `checkout_controller.py` et
    CLAUDE.md § Produits de substitution) : le client choisit toujours,
    jamais le préparateur, donc plus besoin d'un flux post-confirmation.
    """

    def _owned_order(self, order_id=None, order_ref=None):
        partner = request.env.user.partner_id
        domain = [("partner_id", "=", partner.id)]
        if order_id:
            domain.append(("id", "=", order_id))
        elif order_ref:
            domain.append(("name", "=", order_ref))
        else:
            return request.env["sale.order"]
        return request.env["sale.order"].sudo().search(domain, limit=1)

    @http.route("/echango/order/list", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def list_orders(self, offset=0, limit=None, **kw):
        """F09 — historique des commandes. `sale.order` est lisible par le
        portail via `/web/dataset/call_kw` (règle standard restreinte au
        partenaire propriétaire), mais ce chemin échappe à la politique
        "session expirée après 24h d'inactivité" (`require_fresh_session`
        ne s'applique qu'aux contrôleurs `/echango/*`, cf. status-V1.md §
        Sécurité — trouvé à l'audit du 2026-07-19) : endpoint custom pour
        que l'historique de commandes (données personnelles) soit couvert
        lui aussi, pas seulement les mutations panier/checkout/profil.
        """
        partner = request.env.user.partner_id
        orders = request.env["sale.order"].sudo().search(
            [("partner_id", "=", partner.id), ("state", "!=", "draft")],
            order="date_order desc", offset=offset, limit=limit,
        )
        return {
            "orders": [
                {
                    "id": o.id,
                    "name": o.name,
                    "date_order": o.date_order.isoformat() if o.date_order else None,
                    "amount_total": o.amount_total,
                    "state": o.state,
                }
                for o in orders
            ]
        }

    @http.route("/echango/order/detail", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def detail(self, order_ref=None, **kw):
        """F08/F09 — suivi détaillé d'une commande. Même raison que
        `list_orders` ci-dessus : remplace un `search_read` direct
        (`sale.order` + `sale.order.line`) pour rester couvert par la
        politique de fraîcheur de session.
        """
        order = self._owned_order(order_ref=order_ref)
        if not order:
            return {"error": "not_found"}
        return {
            "order": {
                "id": order.id,
                "name": order.name,
                "amount_total": order.amount_total,
                "state": order.state,
                "x_reception_mode": order.x_reception_mode,
                "x_creneau": order.x_creneau.isoformat() if order.x_creneau else None,
            },
            "lines": [
                {"name": line.name, "product_uom_qty": line.product_uom_qty}
                for line in order.order_line
            ],
        }

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

