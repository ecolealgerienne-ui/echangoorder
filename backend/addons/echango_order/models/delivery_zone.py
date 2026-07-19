from odoo import fields, models


class DeliveryZone(models.Model):
    """F07 — zones de livraison couvertes (ville / code postal). Pas de
    notion de zone de livraison simple nativement en Odoo 19 CE, custom
    justifié (voir CLAUDE.md § Custom fields Odoo attendus).

    Géré par le back-office (menu Echango Order), pas exposé au portail via
    call_kw — la vérification d'appartenance se fait via un contrôleur en
    sudo() (`controllers/checkout_controller.py`) pour ne pas avoir à
    ouvrir ce modèle en lecture au portail pour un simple test.
    """

    _name = "x_delivery_zone"
    _description = "Zone de livraison Echango Order"

    name = fields.Char(required=True)
    city = fields.Char(required=True)
    zip_code = fields.Char(string="Code postal")
    active = fields.Boolean(default=True)
