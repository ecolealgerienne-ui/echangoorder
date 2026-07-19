from odoo import fields, models


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
