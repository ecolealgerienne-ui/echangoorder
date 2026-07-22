from collections import Counter

from odoo import api, fields, models
from odoo.exceptions import UserError

from .batch_picking_engine import CandidateOrder, compute_batches

# Préparation groupée des commandes (batch picking + zone de tri) —
# décision produit 2026-07, voir CLAUDE.md § Préparation groupée pour le
# détail complet (3 revues spécialisées avant codage : logistique, Odoo,
# algorithmique). Paramètres réglables via `ir.config_parameter` plutôt
# qu'un nouveau modèle — quelques scalaires, pas besoin d'une table dédiée
# (principe "standard avant custom") ; valeurs par défaut posées par
# `data/batch_picking_data.xml`, modifiables sous Réglages > Technique >
# Paramètres système (mode développeur).
_DEFAULTS = {
    "batch_max_orders": 6,
    "batch_max_qty": 100,
    "batch_max_lines": 40,
    "batch_sla_hours": 4,
}
_DEFAULT_MIN_SIMILARITY = 0.10


class BatchPickingWizard(models.TransientModel):
    """Assistant "Suggérer des lots de préparation" — calcule un
    regroupement de commandes à partir de l'ensemble des commandes
    candidates (pas d'un enregistrement précis, contrairement à
    `x_pin_reset_wizard`) : action de type tableau de bord, sans
    dépendance à `active_id`. L'opérateur ajuste le numéro de lot de
    chaque ligne avant de valider — le calcul ne fait QUE suggérer, aucun
    `stock.picking.batch` n'est créé avant `action_create_batches`.
    """

    _name = "x_batch_picking_wizard"
    _description = "Suggérer des lots de préparation groupée"

    line_ids = fields.One2many("x_batch_picking_wizard_line", "wizard_id", string="Commandes candidates")

    @api.model
    def default_get(self, fields_list):
        res = super().default_get(fields_list)
        if "line_ids" in fields_list:
            res["line_ids"] = self._compute_suggestions()
        return res

    def _get_int_param(self, key):
        return int(self.env["ir.config_parameter"].sudo().get_param(
            f"echango_order.{key}", _DEFAULTS[key]))

    def _get_min_similarity(self):
        return float(self.env["ir.config_parameter"].sudo().get_param(
            "echango_order.batch_min_similarity", _DEFAULT_MIN_SIMILARITY))

    def _candidate_orders(self):
        """Commandes déjà confirmées par un opérateur (`state == 'sale'`,
        voir `sale_order.py.action_confirm`) dont l'étape Pick existe,
        n'est pas terminée/annulée, et n'est pas déjà dans un lot. Une
        commande dont l'entrepôt n'est pas configuré en 3 étapes
        (`pick_type_id` absent) n'a pas d'étape Pick distincte — rien à
        batcher pour elle, le flux historique à 1 étape s'applique tel
        quel sans que ce wizard n'ait besoin de le savoir explicitement.
        """
        orders = self.env["sale.order"].search([("state", "=", "sale")])
        result = []
        for order in orders:
            pick_type = order.warehouse_id.pick_type_id
            if not pick_type:
                continue
            pick = order.picking_ids.filtered(
                lambda p, pick_type=pick_type: p.picking_type_id == pick_type
                and p.state not in ("done", "cancel")
                and not p.batch_id
            )[:1]
            if pick:
                result.append((order, pick))
        return result

    def _compute_suggestions(self):
        candidates = self._candidate_orders()
        if not candidates:
            return []

        max_orders = self._get_int_param("batch_max_orders")
        max_qty = self._get_int_param("batch_max_qty")
        max_lines = self._get_int_param("batch_max_lines")
        sla_hours = self._get_int_param("batch_sla_hours")
        min_similarity = self._get_min_similarity()

        now = fields.Datetime.now()
        engine_orders = []
        by_key = {}
        for order, pick in candidates:
            lines = order.order_line.filtered(lambda l: not l.is_reward_line)
            counts = Counter()
            for line in lines:
                counts[line.product_id.product_tmpl_id.id] += line.product_uom_qty
            # Ancienneté = depuis la création du picking Pick (déclenchée
            # par action_confirm) — pas de champ "date de confirmation"
            # standard distinct sur sale.order, ce proxy est fiable et ne
            # nécessite aucun nouveau champ.
            waiting_hours = (now - pick.create_date).total_seconds() / 3600.0
            engine_orders.append(CandidateOrder(
                key=order.id,
                product_counts=counts,
                line_count=len(lines),
                qty_total=sum(lines.mapped("product_uom_qty")),
                waiting_hours=waiting_hours,
            ))
            by_key[order.id] = pick

        batches = compute_batches(
            engine_orders,
            max_orders=max_orders,
            max_qty=max_qty,
            max_lines=max_lines,
            min_similarity=min_similarity,
            sla_hours=sla_hours,
        )

        commands = []
        for batch_index, batch in enumerate(batches, start=1):
            for key in batch:
                pick = by_key[key]
                # order_id/line_count/qty_total ne sont plus transmis ici :
                # ce sont des champs calculés sur BatchPickingWizardLine
                # (dépendants de picking_id), voir le commentaire sur ce
                # modèle — bug trouvé en test réel (2026-07-22, cf.
                # CLAUDE.md § Préparation groupée) : le client web n'envoie
                # pas les champs readonly peuplés seulement par défaut lors
                # de la création d'un One2many éditable, même avec
                # force_save="1" (insuffisant dans ce cas précis). Seul
                # picking_id (non readonly, juste column_invisible) survit
                # de façon fiable à la sauvegarde côté client.
                commands.append((0, 0, {
                    "picking_id": pick.id,
                    "batch_index": batch_index,
                }))
        return commands

    def action_refresh(self):
        """Relance le calcul (ex. après qu'un opérateur a confirmé
        d'autres commandes depuis l'ouverture du wizard)."""
        self.ensure_one()
        self.line_ids.unlink()
        self.line_ids = self._compute_suggestions()
        return {
            "type": "ir.actions.act_window",
            "res_model": self._name,
            "res_id": self.id,
            "view_mode": "form",
            "target": "new",
        }

    def action_create_batches(self):
        """Matérialise les lots validés (ou ajustés) par l'opérateur en
        vrais `stock.picking.batch` — un batch par valeur distincte de
        `batch_index` parmi les lignes non exclues (0/vide = exclue).
        Crée aussi un `stock.quant.package` par commande, nommé d'après sa
        référence (`order.name`) — convention plutôt qu'un nouveau champ
        de liaison (aucun champ standard ne relie `stock.quant.package` à
        `sale.order`, voir CLAUDE.md § Préparation groupée)."""
        self.ensure_one()
        groups = {}
        for line in self.line_ids:
            if not line.batch_index:
                continue
            groups.setdefault(line.batch_index, self.env["x_batch_picking_wizard_line"])
            groups[line.batch_index] |= line
        if not groups:
            raise UserError("Aucun lot à créer — assignez au moins une commande à un numéro de lot.")

        Batch = self.env["stock.picking.batch"]
        Package = self.env["stock.quant.package"]
        batches = Batch
        for index in sorted(groups):
            lines = groups[index]
            batch = Batch.create({})
            lines.mapped("picking_id").write({"batch_id": batch.id})
            batches |= batch
            for line in lines:
                if not Package.search([("name", "=", line.order_id.name)], limit=1):
                    Package.create({"name": line.order_id.name})

        return {
            "type": "ir.actions.act_window",
            "res_model": "stock.picking.batch",
            "view_mode": "list,form",
            "domain": [("id", "in", batches.ids)],
        }


class BatchPickingWizardLine(models.TransientModel):
    """Une ligne = une commande candidate proposée pour un lot, avec le
    numéro de lot suggéré par le calcul — éditable par l'opérateur avant
    validation (garder un humain dans la boucle, décision produit, voir
    CLAUDE.md § Préparation groupée).

    `order_id`/`line_count`/`qty_total` sont des champs **calculés**
    (dépendants de `picking_id` uniquement) plutôt que peuplés directement
    par `_compute_suggestions()` — bug trouvé en test réel (2026-07-22) :
    le client web n'envoie pas au serveur les champs `readonly="1"`
    peuplés seulement via `default_get` lors de la création des lignes
    d'un One2many éditable, même avec `force_save="1"` (insuffisant ici,
    contrairement à l'usage habituel de cet attribut). En passant par un
    vrai `compute(store=True)`, Odoo recalcule ces valeurs côté serveur à
    partir de `picking_id` (seul champ qui survit de façon fiable à la
    sauvegarde, car non `readonly`) — plus aucune dépendance à ce que le
    client renvoie correctement des champs en lecture seule.
    """

    _name = "x_batch_picking_wizard_line"
    _description = "Commande proposée pour un lot de préparation groupée"

    wizard_id = fields.Many2one("x_batch_picking_wizard", required=True, ondelete="cascade")
    picking_id = fields.Many2one("stock.picking", string="Bon de collecte (Pick)", required=True)
    order_id = fields.Many2one(
        "sale.order", string="Commande",
        compute="_compute_order_fields", store=True,
    )
    line_count = fields.Integer(string="Nb lignes", compute="_compute_order_fields", store=True)
    qty_total = fields.Float(string="Quantité totale", compute="_compute_order_fields", store=True)
    batch_index = fields.Integer(
        string="N° de lot suggéré",
        help="0 ou vide = commande exclue de ce cycle, ne sera pas regroupée. "
             "Modifiable avant de cliquer sur \"Créer les lots\" — des lignes "
             "avec le même numéro rejoignent le même stock.picking.batch.",
    )

    @api.depends("picking_id")
    def _compute_order_fields(self):
        for line in self:
            order = line.picking_id.sale_id
            order_lines = order.order_line.filtered(lambda l: not l.is_reward_line)
            line.order_id = order.id
            line.line_count = len(order_lines)
            line.qty_total = sum(order_lines.mapped("product_uom_qty"))
