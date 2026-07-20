from odoo import fields, http
from odoo.http import request

from .rate_limit import rate_limited
from .session_utils import require_fresh_session


class EchangoCatalogController(http.Controller):
    """Disponibilité stock (F04/F05) sans ouvrir tout le module stock au
    portail. `qty_available` reste le champ calculé standard d'Odoo — seule
    la façon de le lire change : en `sudo()` dans un contrôleur étroit,
    plutôt qu'un `search_read`/`read` portail qui déclenche en cascade des
    `AccessError` sur `product.product` puis `stock.warehouse` (constaté en
    testant F04, voir status-V1.md § Points de vigilance).
    """

    @http.route("/echango/currency", type="jsonrpc", auth="public", methods=["POST"], csrf=False)
    @rate_limited("currency", limit=60, window_minutes=1)
    def currency(self, **kw):
        """Symbole/position de la devise réellement configurée sur la
        société (`res.company.currency_id`, standard) — l'app affichait
        auparavant un "€" en dur partout, incorrect dès que la société
        n'est pas en EUR (constaté par l'utilisateur : société de test en
        USD). `auth="public"` : la vitrine (F00) affiche aussi des prix
        avant connexion.
        """
        currency = request.env.company.sudo().currency_id
        return {"symbol": currency.symbol, "position": currency.position}

    @http.route("/echango/catalog/stock", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def stock(self, product_ids=None, **kw):
        ids = [int(i) for i in (product_ids or [])]
        templates = request.env["product.template"].sudo().search([
            ("id", "in", ids), ("sale_ok", "=", True),
        ])
        return {"stock": {str(t.id): t.qty_available for t in templates}}

    @http.route("/echango/catalog/promotions", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
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
        Le pourcentage affiché sur le badge (demande utilisateur) n'a de
        sens que pour une récompense en pourcentage (`discount_mode`
        "percent" — vérifié contre le code source, pas "discount_type").
        Une remise en montant fixe/par point reste badgée mais sans
        pourcentage (`None`) plutôt que d'afficher un montant trompeur sur
        une tuile qui n'affiche qu'un prix unitaire. Si plusieurs
        récompenses actives visent le même produit, on garde le
        pourcentage le plus avantageux.
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
        promotions = {}
        for reward in rewards:
            percent = reward.discount if reward.discount_mode == "percent" else None
            for tmpl_id in reward.all_discount_product_ids.product_tmpl_id.ids:
                if tmpl_id not in ids:
                    continue
                current = promotions.get(tmpl_id)
                if tmpl_id not in promotions or (percent or 0) > (current or 0):
                    promotions[tmpl_id] = percent
        return {"promotions": {str(tmpl_id): percent for tmpl_id, percent in promotions.items()}}

    @http.route("/echango/catalog/substitutes", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def substitutes(self, product_id=None, **kw):
        """F05 — produits de substitution affichés sur la fiche produit
        (`x_substitute_product_ids`, curation manuelle admin — voir
        `models/product_template.py`). Même raison que `stock()`/
        `promotions()` ci-dessus : résolution en `sudo()` plutôt qu'un
        `search_read` portail sur le champ Many2many brut (juste des ids,
        pas de nom/prix/image sans un second appel).
        """
        template = request.env["product.template"].sudo().search([("id", "=", product_id)], limit=1)
        if not template:
            return {"substitutes": []}
        substitutes = template.x_substitute_product_ids.filtered(lambda t: t.sale_ok)
        return {
            "substitutes": [
                {
                    "id": t.id,
                    "name": t.display_name,
                    "list_price": t.list_price,
                    "image_128": t.image_128.decode() if t.image_128 else None,
                    "qty_available": t.qty_available,
                }
                for t in substitutes
            ]
        }

    @http.route("/echango/catalog/variants", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def variants(self, product_id=None, **kw):
        """F05 — sélection de variante (couleur/taille...) sur la fiche
        produit. Mécanisme 100% standard Odoo (`attribute_line_ids`,
        `product_template_attribute_value_ids`, `product_variant_ids`) —
        jusqu'ici totalement ignoré par l'app, qui n'ajoutait toujours que
        `template.product_variant_id` (la variante par défaut). Résolution
        en `sudo()` même raison que `stock()`/`substitutes()` ci-dessus.
        Renvoie la liste complète des variantes avec leur combinaison
        d'attributs plutôt que d'utiliser `_get_variant_for_combination()`
        côté serveur : l'app résout elle-même la variante correspondant à
        la sélection en cours (simple recherche d'ensemble), et ça permet
        d'afficher le stock/prix de chaque combinaison sans aller-retour
        supplémentaire par variante.
        """
        template = request.env["product.template"].sudo().search([("id", "=", product_id)], limit=1)
        if not template:
            return {"attributes": [], "variants": []}
        attributes = [
            {
                "attribute_id": line.attribute_id.id,
                "name": line.attribute_id.name,
                "values": [{"id": ptav.id, "name": ptav.name} for ptav in line.product_template_value_ids],
            }
            for line in template.attribute_line_ids
        ]
        variants = [
            {
                "id": variant.id,
                # ids `product.template.attribute.value` composant cette
                # variante — comparés côté app à la sélection en cours pour
                # trouver la variante exacte (un ensemble par combinaison).
                "attribute_value_ids": variant.product_template_attribute_value_ids.ids,
                "list_price": variant.lst_price,
                "qty_available": variant.qty_available,
                "image_128": variant.image_128.decode() if variant.image_128 else None,
            }
            for variant in template.product_variant_ids
        ]
        return {"attributes": attributes, "variants": variants}
