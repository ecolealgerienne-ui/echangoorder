from odoo import fields, models

# Préparation groupée (batch picking + zone de tri) — décision produit
# 2026-07, voir CLAUDE.md § Préparation groupée. Ces paramètres étaient
# jusqu'ici réglables uniquement via Réglages > Technique > Paramètres
# système (mode développeur, ir.config_parameter direct) — signalé peu
# accessible par l'utilisateur en test réel. `config_parameter` est le
# mécanisme standard de `res.config.settings` pour lire/écrire un
# `ir.config_parameter` depuis un champ de formulaire classique, sans
# aucun code de lecture/écriture custom (get_values()/set_values()) — la
# vue dédiée (views/batch_picking_settings_views.xml) reste volontairement
# en dehors de l'app Réglages générale (pas d'intégration dans le formulaire
# géant de base.res_config_settings_view_form), un simple menu sous
# "Echango Order" suffit pour ce besoin.


class ResConfigSettings(models.TransientModel):
    _inherit = "res.config.settings"

    x_batch_max_orders = fields.Integer(
        string="Bacs disponibles au poste de tri",
        config_parameter="echango_order.batch_max_orders", default=6,
        help="Nombre maximal de commandes regroupées dans un même lot de collecte.",
    )
    x_batch_max_qty = fields.Integer(
        string="Charge opérateur max (quantité cumulée)",
        config_parameter="echango_order.batch_max_qty", default=100,
        help="Somme des quantités d'articles au-delà de laquelle un lot n'accepte plus de commande supplémentaire.",
    )
    x_batch_max_lines = fields.Integer(
        string="Plafond de lignes au poste de tri",
        config_parameter="echango_order.batch_max_lines", default=40,
        help="Proxy du temps de traitement au poste de tri — nombre de lignes de commande cumulées maximal par lot.",
    )
    x_batch_min_similarity = fields.Float(
        string="Seuil minimal de similarité",
        config_parameter="echango_order.batch_min_similarity", default=0.10,
        help="Entre 0 et 1 (Jaccard sur les produits). En dessous, deux commandes ne sont jamais regroupées.",
    )
    x_batch_sla_hours = fields.Integer(
        string="Délai avant priorité forcée (heures)",
        config_parameter="echango_order.batch_sla_hours", default=4,
        help="Une commande qui attend plus longtemps que ce délai devient prioritaire dans le prochain lot, quelle que soit sa similarité avec les autres.",
    )
