from odoo import fields, models
from odoo.exceptions import UserError


class SaleOrder(models.Model):
    _inherit = "sale.order"

    # F07 — mode de réception et créneau (voir CLAUDE.md § Custom fields
    # Odoo attendus). Aucun champ standard équivalent sur sale.order.
    x_reception_mode = fields.Selection(
        [("home_delivery", "Livraison à domicile"), ("pickup", "Retrait en magasin")],
        string="Mode de réception",
    )
    # Début du créneau — durée fixe de 2h par convention côté app (pas de
    # champ de fin séparé, cf. status-V1.md pour la justification).
    x_creneau = fields.Datetime(string="Créneau (début)")

    # F08 — cycle de vie de la commande revu (décision produit 2026-07,
    # voir CLAUDE.md § Statuts de commande) : réutilise `sent` ("Devis
    # envoyé"), valeur standard déjà présente dans le Selection `state` de
    # `sale.order` mais jusqu'ici jamais utilisée par ce module — relabel
    # uniquement (`selection_add`), même champ, même mécanisme. Le client
    # "confirme sa commande" dans l'app (`checkout_controller.py.confirm()`)
    # sans appeler `action_confirm()` : la commande passe seulement en
    # `sent`, reste modifiable (voir `cart_controller.py`, domaine étendu à
    # `draft`/`sent`), et n'est verrouillée/envoyée en préparation que
    # lorsqu'un opérateur clique sur le bouton standard "Confirmer" en
    # back-office — aucun nouveau bouton nécessaire pour cette étape,
    # `action_confirm()` fait déjà exactement ce qu'il faut (verrouille le
    # portail, génère le `stock.picking`).
    state = fields.Selection(selection_add=[("sent", "En attente de prise en charge")])

    # F08 — étape transporteur (décision produit 2026-07) : aucun
    # équivalent standard pour "un livreur humain est en route" sans
    # intégration transport réelle (GPS, app dédiée — hors périmètre
    # Phase 1, cf. CLAUDE.md §5) — champ custom justifié, limité aux 2
    # seules valeurs qui ne se déduisent pas déjà du `stock.picking`
    # (lui-même déjà exploité pour "Prête", voir `order_controller.py.
    # _prep_status`). Uniquement pour une livraison à domicile — pour un
    # retrait en magasin, voir `x_pickup_collected` ci-dessous.
    x_delivery_status = fields.Selection(
        [("out_for_delivery", "En cours de livraison"), ("delivered", "Livrée")],
        string="Statut de livraison",
    )

    # F08 — même problème que x_delivery_status ci-dessus, côté retrait
    # magasin (signalé par l'utilisateur en test réel) : valider le bon de
    # livraison (`stock.picking.done`) veut dire "l'opérateur a fini de
    # préparer", pas "le client est passé le récupérer" — deux événements
    # distincts, initialement confondus en un seul (`prep_status ==
    # 'completed'` -> "Récupérée" directement). Aucun équivalent standard
    # pour "le client s'est présenté au comptoir" sans un vrai système de
    # pointage — champ custom justifié, même schéma que x_delivery_status.
    x_pickup_collected = fields.Boolean(string="Récupérée en magasin")

    def action_mark_out_for_delivery(self):
        for order in self:
            if order.x_reception_mode != "home_delivery":
                raise UserError("Uniquement pour une commande en livraison à domicile.")
            order.x_delivery_status = "out_for_delivery"

    def action_mark_delivered(self):
        for order in self:
            if order.x_reception_mode != "home_delivery":
                raise UserError("Uniquement pour une commande en livraison à domicile.")
            order.x_delivery_status = "delivered"

    def action_mark_picked_up(self):
        for order in self:
            if order.x_reception_mode != "pickup":
                raise UserError("Uniquement pour une commande en retrait magasin.")
            order.x_pickup_collected = True

    def action_confirm(self):
        """Favoris (`x_product_favorite`, décision produit — voir
        CLAUDE.md § Favoris) déplacés ici depuis `checkout_controller.py`
        (qui appelait auparavant `action_confirm()` directement) : la
        confirmation réelle se fait désormais via ce bouton standard,
        cliqué par un opérateur en back-office (voir `state` ci-dessus) —
        centraliser ici garantit que les favoris se mettent à jour quel
        que soit le chemin de confirmation (app ou back-office direct),
        plutôt que de dépendre d'un appel explicite dans un contrôleur
        précis."""
        res = super().action_confirm()
        for order in self:
            order._seed_favorites()
        return res

    def _seed_favorites(self):
        self.ensure_one()
        favorite = self.env["x_product_favorite"].sudo()
        existing = set(favorite.search([("partner_id", "=", self.partner_id.id)]).product_tmpl_id.ids)
        for line in self.order_line.filtered(lambda l: not l.is_reward_line):
            tmpl_id = line.product_id.product_tmpl_id.id
            if tmpl_id not in existing:
                favorite.create({"partner_id": self.partner_id.id, "product_tmpl_id": tmpl_id})
                existing.add(tmpl_id)
