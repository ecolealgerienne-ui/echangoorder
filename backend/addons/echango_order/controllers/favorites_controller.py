from odoo import http
from odoo.http import request


class EchangoFavoritesController(http.Controller):
    """Liste de produits favoris (`x_product_favorite`) : initialisée
    automatiquement à chaque commande confirmée (voir
    `checkout_controller.py._seed_favorites`) puis modifiable manuellement
    par le client (ajout/retrait). `product.template` n'est pas exposé en
    écriture au portail (F03/F04) : ce contrôleur agit en `sudo()`.
    """

    @http.route("/echango/favorites", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def list_favorites(self, **kw):
        partner = request.env.user.partner_id
        favorites = request.env["x_product_favorite"].sudo().search([("partner_id", "=", partner.id)])
        templates = favorites.product_tmpl_id.filtered("sale_ok")
        return {
            "products": [
                {
                    "id": t.id,
                    "name": t.name,
                    "list_price": t.list_price,
                    "image_128": t.image_128.decode() if t.image_128 else None,
                }
                for t in templates
            ]
        }

    @http.route("/echango/favorites/add", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def add_favorite(self, product_id=None, **kw):
        partner = request.env.user.partner_id
        template = request.env["product.template"].sudo().search(
            [("id", "=", product_id), ("sale_ok", "=", True)], limit=1,
        )
        if not template:
            return {"error": "not_found"}
        favorite = request.env["x_product_favorite"].sudo()
        if not favorite.search_count([("partner_id", "=", partner.id), ("product_tmpl_id", "=", template.id)]):
            favorite.create({"partner_id": partner.id, "product_tmpl_id": template.id})
        return {"success": True}

    @http.route("/echango/favorites/remove", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def remove_favorite(self, product_id=None, **kw):
        partner = request.env.user.partner_id
        request.env["x_product_favorite"].sudo().search([
            ("partner_id", "=", partner.id), ("product_tmpl_id", "=", product_id),
        ]).unlink()
        return {"success": True}
