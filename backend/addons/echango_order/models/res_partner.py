from odoo import fields, models


class ResPartner(models.Model):
    _inherit = "res.partner"

    x_adresse_favorite = fields.Boolean(
        string="Adresse favorite",
        help="F10 — une adresse de livraison (contact enfant type='delivery') "
        "peut être marquée favorite, une seule à la fois par client. Champ "
        "custom car Odoo n'a pas de notion de 'default address' parmi les "
        "contacts d'un partenaire — voir CLAUDE.md § Principe architecture Odoo.",
    )
