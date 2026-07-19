from odoo import fields, http
from odoo.http import request


class EchangoCatalogController(http.Controller):
    """Disponibilité stock (F04/F05) sans ouvrir tout le module stock au
    portail. `qty_available` reste le champ calculé standard d'Odoo — seule
    la façon de le lire change : en `sudo()` dans un contrôleur étroit,
    plutôt qu'un `search_read`/`read` portail qui déclenche en cascade des
    `AccessError` sur `product.product` puis `stock.warehouse` (constaté en
    testant F04, voir status-V1.md § Points de vigilance).
    """

    @http.route("/echango/catalog/stock", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def stock(self, product_ids=None, **kw):
        ids = [int(i) for i in (product_ids or [])]
        templates = request.env["product.template"].sudo().search([
            ("id", "in", ids), ("sale_ok", "=", True),
        ])
        return {"stock": {str(t.id): t.qty_available for t in templates}}

    @http.route("/echango/catalog/promotions", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def promotions(self, product_ids=None, **kw):
        """Badge "Promo" sur le catalogue (Accueil/Catalogue/Recherche/
        Favoris) — demande utilisateur suite à un wireframe de référence.
        Module standard `loyalty` (déjà utilisé pour F15) : une promotion
        automatique (`program_type` "promotion"/"buy_x_get_y", `trigger`
        "auto" — pas de code, contrairement à F15) et une récompense de
        type remise sur des produits précis. On ne s'occupe pas des cas
        "remise sur toute la commande"/"produit le moins cher" (pas de sens
        au niveau d'une tuile produit isolée) ni des codes promo (F15,
        nécessitent une saisie, pas un badge passif).
        `all_discount_product_ids` (champ calculé standard) résout déjà les
        produits concernés qu'ils soient listés un par un ou via une
        catégorie/étiquette/domaine — pas besoin de réimplémenter cette
        logique.
        """
        ids = [int(i) for i in (product_ids or [])]
        today = fields.Date.today()
        programs = request.env["loyalty.program"].sudo().search([
            ("active", "=", True),
            ("program_type", "in", ("promotion", "buy_x_get_y")),
            ("trigger", "=", "auto"),
        ])
        programs = programs.filtered(
            lambda p: (not p.date_from or p.date_from <= today) and (not p.date_to or p.date_to >= today)
        )
        rewards = programs.reward_ids.filtered(
            lambda r: r.reward_type == "discount" and r.discount_applicability == "specific"
        )
        promoted_tmpl_ids = rewards.all_discount_product_ids.product_tmpl_id.ids
        return {"promoted_ids": [tid for tid in promoted_tmpl_ids if tid in ids]}
