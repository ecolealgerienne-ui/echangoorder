from odoo import fields, models


class TimeslotCapacity(models.Model):
    """F07 — capacité des créneaux ("créneau complet grisé", specs QA).
    Pas de notion de créneau/capacité nativement en Odoo 19 CE — modèle
    custom justifié (voir CLAUDE.md § Custom fields Odoo attendus).

    Les créneaux eux-mêmes restent générés côté client
    (`mobile/lib/utils/timeslots.dart`, seule source de vérité — fenêtres
    fixes de 2h à heures fixes) : ce modèle ne fait que déclarer, par heure
    de début et mode de réception, un nombre maximum de commandes
    acceptées. Pas de capacité configurée pour une heure donnée -> jamais
    complet (comportement par défaut inchangé), voir
    `controllers/checkout_controller.py.timeslots`.
    """

    _name = "x_timeslot_capacity"
    _description = "Capacité des créneaux Echango Order"

    reception_mode = fields.Selection(
        [("home_delivery", "Livraison à domicile"), ("pickup", "Retrait en magasin")],
        required=True,
    )
    hour = fields.Integer(string="Heure de début", required=True, help="0-23, doit correspondre à une des heures de créneau générées côté app (utils/timeslots.dart).")
    max_orders = fields.Integer(string="Commandes max sur ce créneau", required=True, default=20)

    _reception_mode_hour_uniq = models.Constraint(
        "unique(reception_mode, hour)",
        "Une seule capacité par heure et par mode de réception.",
    )
