{
    "name": "Echango Order",
    "version": "19.0.1.0.0",
    "category": "Sales",
    "summary": "Backend custom pour l'app mobile Echango Order (F00-F17)",
    "description": """
Module custom Echango Order
============================
Regroupe les champs et endpoints spécifiques à l'app mobile Echango Order
(commande alimentaire, livraison/retrait) — voir docs/specs_phase1_echango_order.md
et CLAUDE.md à la racine du repo pour le détail fonctionnel.

Squelette pour l'instant : modèles/champs/endpoints ajoutés au fur et à
mesure du branchement de chaque écran (F02 auth en premier).
    """,
    "author": "Echango",
    "license": "LGPL-3",
    "depends": ["base", "portal", "sale", "stock"],
    "data": [
        "security/ir.model.access.csv",
        "security/ir_rule.xml",
        "views/delivery_zone_views.xml",
        "views/sale_order_views.xml",
        "views/product_template_views.xml",
    ],
    "installable": True,
    "application": True,
}
