from odoo import http
from odoo.exceptions import UserError
from odoo.http import request

from .session_utils import require_fresh_session

# F08 — statut de préparation (décision produit 2026-07) : réutilise le
# `stock.picking` (bon de livraison) qu'Odoo génère automatiquement à la
# confirmation d'une commande (module `stock`, déjà dépendance du module) —
# aucun champ/modèle custom, aucune app préparateur/transporteur dédiée.
# Volontairement réduit à 3 statuts simples plutôt que d'exposer les 5+
# états techniques de `stock.picking` (non parlants pour un client) :
# - "pending" (draft/waiting/confirmed) : pas encore prêt.
# - "ready" (assigned) : stock réservé, prêt à livrer/retirer.
# - "completed" (done) : livré ou retiré, le picking est validé.
# `cancel` volontairement absent : le statut de la commande elle-même
# (`sale.order.state == 'cancel'`) fait déjà foi pour ce cas côté app.
_PICKING_STATUS_MAP = {
    "draft": "pending",
    "waiting": "pending",
    "confirmed": "pending",
    "assigned": "ready",
    "done": "completed",
}


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

    def _prep_status(self, order):
        """F08 — voir _PICKING_STATUS_MAP ci-dessus. Une commande peut
        avoir plusieurs `stock.picking` dans des cas avancés (reliquat
        partiel...) — on ne s'intéresse ici qu'au principal bon de
        livraison sortant, le plus récent (`id desc`), suffisant pour la
        simplicité recherchée en Phase 1 (pas de vrai suivi préparateur
        multi-étapes)."""
        picking = order.picking_ids.filtered(lambda p: p.picking_type_id.code == "outgoing")
        picking = picking.sorted("id", reverse=True)[:1]
        if not picking or picking.state == "cancel":
            return None
        return _PICKING_STATUS_MAP.get(picking.state)

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
                    "x_reception_mode": o.x_reception_mode or None,
                    "prep_status": self._prep_status(o),
                    # Un champ Selection non renseigné vaut `False` côté
                    # ORM Odoo (pas `None`) — sérialisé en JSON comme un
                    # booléen, pas `null`. Normalisé ici en `None` : sinon
                    # `x_delivery_status as String?` côté Flutter plante
                    # (`type 'bool' is not a subtype of type 'String?'`)
                    # pour toute commande où l'opérateur n'a pas encore
                    # cliqué "Marquer en cours de livraison"/"livrée", donc
                    # la quasi-totalité des commandes.
                    "x_delivery_status": o.x_delivery_status or None,
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
                # Même piège que x_delivery_status ci-dessous (Selection
                # non renseigné -> False côté ORM, pas None) : `detail()`
                # n'a pas de filtre sur `state`/`x_reception_mode`
                # contrairement à `list_orders()`, une commande dont ce
                # champ n'a jamais été écrit peut donc légitimement
                # atteindre ce point. `order_tracking_screen.dart` fait
                # `as String?` dessus sans repli, plantage confirmé par
                # audit.
                "x_reception_mode": order.x_reception_mode or None,
                "x_creneau": order.x_creneau.isoformat() if order.x_creneau else None,
                "prep_status": self._prep_status(order),
                "x_delivery_status": order.x_delivery_status or None,
            },
            "lines": [
                {"name": line.name, "product_uom_qty": line.product_uom_qty}
                for line in order.order_line
            ],
        }

    def _can_cancel(self, order):
        """F16 — décision produit 2026-07 (revue suite à un bug signalé :
        le bouton "Annuler" restait affiché même pour une commande déjà
        livrée). `state == 'sale'` ne suffit plus comme critère depuis la
        refonte du cycle de vie (F08, voir CLAUDE.md § Statuts de
        commande) : il reste `'sale'` de la prise en charge jusqu'à la
        livraison, il ne se remet plus à jour ensuite. Le vrai critère est
        `prep_status` — annulable tant que l'opérateur n'a pas fini de la
        préparer ("Prête" ou au-delà = trop tard, colis déjà préparé/parti/
        remis). `None` (pas de `stock.picking`, ex. produit non suivi en
        stock) traité comme "pas encore prêt" : rien à annuler côté
        entrepôt dans ce cas, l'annulation reste possible.
        """
        if order.state == "sent":
            return True
        if order.state == "sale":
            return self._prep_status(order) in (None, "pending")
        return False

    @http.route("/echango/order/cancel", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def cancel(self, order_id=None, **kw):
        order = self._owned_order(order_id)
        if not order:
            return {"error": "not_found"}
        if not self._can_cancel(order):
            return {"error": "order.cannot_cancel"}
        try:
            order.sudo().action_cancel()
        except UserError:
            return {"error": "order.cannot_cancel"}
        return {"success": True}

