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


class SaleOrderLine(models.Model):
    _inherit = "sale.order.line"

    # F17 — produit suggéré par le préparateur en cas de rupture de stock à
    # la préparation (signalement manuel en back-office, Phase 1 — voir
    # CLAUDE.md § Custom fields Odoo attendus, aucun équivalent standard).
    # Présence de ce champ = substitution en attente de réponse du client ;
    # vidé si acceptée (le produit de la ligne est alors remplacé), ou la
    # ligne entière est supprimée si refusée — voir
    # `controllers/order_controller.py`.
    x_substitution_produit = fields.Many2one(
        "product.product", string="Substitution proposée", domain=[("sale_ok", "=", True)],
    )
