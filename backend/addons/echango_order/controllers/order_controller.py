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

    def _owned_line(self, line_id):
        partner = request.env.user.partner_id
        return request.env["sale.order.line"].sudo().search([
            ("id", "=", line_id), ("order_id.partner_id", "=", partner.id),
        ], limit=1)

    @http.route("/echango/order/substitution", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def get_substitution(self, order_id=None, order_ref=None, **kw):
        # F17 — le signalement de rupture + la suggestion sont saisis
        # manuellement par le préparateur en back-office (`x_substitution_
        # produit` sur la ligne, voir `views/sale_order_views.xml`) : côté
        # app, on se contente de lire s'il y en a une en attente pour cette
        # commande. `product.product` n'étant pas exposé au portail (voir
        # CLAUDE.md § Sécurité / F04), la résolution du nom/prix se fait ici
        # en `sudo()`, pas via un `search_read` direct côté client.
        # `order_ref` (nom de commande) accepté en plus de `order_id` :
        # évite à `SubstitutionScreen` de devoir d'abord résoudre l'id via
        # un `search_read` séparé (non couvert par `require_fresh_session`,
        # voir `list_orders` ci-dessus).
        order = self._owned_order(order_id=order_id, order_ref=order_ref)
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
