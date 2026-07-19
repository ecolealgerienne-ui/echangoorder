from odoo import http
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
