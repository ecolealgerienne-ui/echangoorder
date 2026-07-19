from odoo import fields, models


class ProductTemplate(models.Model):
    _inherit = "product.template"

    # F00 — vitrine publique (visiteur sans compte). Aucun équivalent
    # standard sans le module `website_sale` (non installé) — voir
    # CLAUDE.md § Custom fields Odoo attendus.
    x_vitrine_publique = fields.Boolean(string="Visible en vitrine publique")
