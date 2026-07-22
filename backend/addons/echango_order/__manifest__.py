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
    "depends": ["base", "mail", "portal", "sale", "stock", "sale_loyalty"],
    "data": [
        "security/ir.model.access.csv",
        "security/ir_rule.xml",
        "data/loyalty_config.xml",
        "data/rate_limit_data.xml",
        "data/batch_picking_data.xml",
        "views/delivery_zone_views.xml",
        "views/timeslot_capacity_views.xml",
        "views/product_template_views.xml",
        "views/sale_order_views.xml",
        "views/res_partner_views.xml",
        "views/res_users_views.xml",
        "views/batch_picking_wizard_views.xml",
        "views/batch_picking_settings_views.xml",
    ],
    "installable": True,
    "application": True,
}
