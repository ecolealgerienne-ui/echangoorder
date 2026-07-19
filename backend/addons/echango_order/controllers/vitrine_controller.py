from odoo import http
from odoo.http import request


class EchangoVitrineController(http.Controller):
    """F00 — vitrine publique (visiteur sans compte, aucune session Odoo).
    `product.template` n'est lisible par le portail qu'après connexion
    (F03/F04, groupe `base.group_portal`) : un simple visiteur n'a même pas
    cette session-là. Endpoint public dédié (`auth='public'`), en
    `sudo()`, filtré `sale_ok` ET `x_vitrine_publique` (curation manuelle
    depuis le back-office, specs Expert Odoo) — pas d'ouverture d'accès ORM
    au groupe `base.group_public`, même logique de non-surexposition que
    pour le portail (cf. CLAUDE.md § Sécurité).
    """

    @http.route("/echango/vitrine/products", type="jsonrpc", auth="public", methods=["POST"], csrf=False)
    def products(self, **kw):
        templates = request.env["product.template"].sudo().search([
            ("sale_ok", "=", True), ("x_vitrine_publique", "=", True),
        ])
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
