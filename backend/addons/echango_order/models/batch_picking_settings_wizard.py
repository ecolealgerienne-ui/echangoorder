from odoo import api, fields, models

# Préparation groupée (batch picking + zone de tri) — décision produit
# 2026-07, voir CLAUDE.md § Préparation groupée.
#
# Historique : d'abord implémenté via une extension de `res.config.settings`
# (mécanisme standard `config_parameter=...`, sans code de lecture/écriture).
# Abandonné suite à un problème trouvé en test réel : Odoo traite ce modèle
# de façon spéciale et l'ouvre toujours dans la coquille complète de l'app
# Réglages (barre "Settings > General Settings > ..."), pas comme un simple
# dialogue — impossible de revenir à l'écran d'origine. Remplacé par un
# assistant dédié, même pattern fiable que `x_batch_picking_wizard` : un
# TransientModel ordinaire, lecture/écriture explicite de
# `ir.config_parameter` (quelques lignes, pas de nouveau modèle persistant
# pour autant — toujours pas de table dédiée pour 5 scalaires).


class BatchPickingSettingsWizard(models.TransientModel):
    _name = "x_batch_picking_settings_wizard"
    _description = "Paramètres de préparation groupée"

    batch_max_orders = fields.Integer(
        string="Bacs disponibles au poste de tri", default=6,
        help="Nombre maximal de commandes regroupées dans un même lot de collecte.",
    )
    batch_max_qty = fields.Integer(
        string="Charge opérateur max (quantité cumulée)", default=100,
        help="Somme des quantités d'articles au-delà de laquelle un lot n'accepte plus de commande supplémentaire.",
    )
    batch_max_lines = fields.Integer(
        string="Plafond de lignes au poste de tri", default=40,
        help="Proxy du temps de traitement au poste de tri — nombre de lignes de commande cumulées maximal par lot.",
    )
    batch_min_similarity = fields.Float(
        string="Seuil minimal de similarité", default=0.10,
        help="Entre 0 et 1 (Jaccard sur les produits). En dessous, deux commandes ne sont jamais regroupées.",
    )
    batch_sla_hours = fields.Integer(
        string="Délai avant priorité forcée (heures)", default=4,
        help="Une commande qui attend plus longtemps que ce délai devient prioritaire dans le prochain lot, quelle que soit sa similarité avec les autres.",
    )

    @api.model
    def default_get(self, fields_list):
        res = super().default_get(fields_list)
        icp = self.env["ir.config_parameter"].sudo()
        if "batch_max_orders" in fields_list:
            res["batch_max_orders"] = int(icp.get_param("echango_order.batch_max_orders", 6))
        if "batch_max_qty" in fields_list:
            res["batch_max_qty"] = int(icp.get_param("echango_order.batch_max_qty", 100))
        if "batch_max_lines" in fields_list:
            res["batch_max_lines"] = int(icp.get_param("echango_order.batch_max_lines", 40))
        if "batch_min_similarity" in fields_list:
            res["batch_min_similarity"] = float(icp.get_param("echango_order.batch_min_similarity", 0.10))
        if "batch_sla_hours" in fields_list:
            res["batch_sla_hours"] = int(icp.get_param("echango_order.batch_sla_hours", 4))
        return res

    def action_save(self):
        self.ensure_one()
        icp = self.env["ir.config_parameter"].sudo()
        icp.set_param("echango_order.batch_max_orders", self.batch_max_orders)
        icp.set_param("echango_order.batch_max_qty", self.batch_max_qty)
        icp.set_param("echango_order.batch_max_lines", self.batch_max_lines)
        icp.set_param("echango_order.batch_min_similarity", self.batch_min_similarity)
        icp.set_param("echango_order.batch_sla_hours", self.batch_sla_hours)
        return {"type": "ir.actions.act_window_close"}
