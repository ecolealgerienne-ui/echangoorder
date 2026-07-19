from odoo import fields, models


class ProductFavorite(models.Model):
    _name = "x_product_favorite"
    _description = "Produit favori client"

    # Liste de favoris initialisée automatiquement à chaque commande
    # confirmée (produits achetés, dédupliqués — voir
    # controllers/checkout_controller.py) et modifiable manuellement par
    # le client (ajout/retrait, controllers/favorites_controller.py).
    # Aucun équivalent standard sans le module website_sale (non
    # installé) — modèle custom minimal, justifié.
    partner_id = fields.Many2one("res.partner", required=True, ondelete="cascade")
    product_tmpl_id = fields.Many2one("product.template", required=True, ondelete="cascade")

    _partner_product_uniq = models.Constraint(
        "unique(partner_id, product_tmpl_id)",
        "Ce produit est déjà dans les favoris.",
    )
