from odoo import fields, models


class ProductTemplate(models.Model):
    _inherit = "product.template"

    # F00 — vitrine publique (visiteur sans compte). Aucun équivalent
    # standard sans le module `website_sale` (non installé) — voir
    # CLAUDE.md § Custom fields Odoo attendus.
    x_vitrine_publique = fields.Boolean(string="Visible en vitrine publique")

    # Sécurité (§9 status-V1.md, audit du filtrage API) : `product.template`
    # est accordé en lecture au groupe portail (`access_product_template_
    # portal`, restreint aux produits vendables via `ir_rule.xml`), mais
    # ir.model.access ne filtre que les LIGNES, pas les CHAMPS — un appel
    # direct à `/web/dataset/call_kw` (hors app, ex. curl avec une session
    # portail valide) pourrait demander n'importe quel champ du modèle, y
    # compris le prix de revient, jamais censé être visible d'un client.
    # `standard_price` n'a aucune restriction `groups` dans le module
    # `product` standard (les restrictions vues dans le backoffice sont
    # au niveau des VUES, sans effet sur l'ORM/API) — surcharge minimale
    # ici plutôt qu'un champ dupliqué, seul l'attribut `groups` change.
    standard_price = fields.Float(groups="base.group_user")

    # Produits de substitution (décision produit 2026-07, remplace F17 —
    # voir CLAUDE.md § Produits de substitution). Aucun équivalent standard :
    # le module OCA `stock_picking_product_interchangeable` a été vérifié
    # avant de créer ce champ (recherche faite, pas juste supposée) mais ne
    # convient pas — relation symétrique, substitution automatique côté
    # entrepôt sans interaction client, alors qu'ici c'est le client qui
    # choisit, sur la fiche produit et/ou au checkout. Curation manuelle
    # admin uniquement (jamais par le préparateur), relation volontairement
    # asymétrique (`relation`/`column1`/`column2` explicites : self-m2m sans
    # champ "inverse" correspondant).
    x_substitute_product_ids = fields.Many2many(
        "product.template",
        relation="x_product_template_substitute_rel",
        column1="product_tmpl_id",
        column2="substitute_tmpl_id",
        string="Produits de substitution",
    )


class ProductProduct(models.Model):
    _inherit = "product.product"

    # Même raisonnement que ci-dessus : `product.product.standard_price`
    # est le champ réel (par variante), `product.template.standard_price`
    # n'est qu'une vue agrégée dessus.
    standard_price = fields.Float(groups="base.group_user")
