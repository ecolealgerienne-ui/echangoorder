import re

from odoo import fields, models
from odoo.exceptions import UserError

PIN_RE = re.compile(r"^\d{6,12}$")


class PinResetWizard(models.TransientModel):
    """F02 — "PIN oublié" : bouton "Réinitialiser le PIN" sur la fiche
    utilisateur (`views/res_users_views.xml`), pour le modérateur qui a
    recontacté le client suite à une demande (`res_partner._notify_pin_
    reset_requested`). Assistant Odoo standard (`TransientModel`, purgé
    automatiquement par le mécanisme natif d'Odoo) plutôt qu'un flux SMS,
    aucun fournisseur choisi (cf. status-V1.md).
    """

    _name = "x_pin_reset_wizard"
    _description = "Réinitialiser le PIN d'un client"

    user_id = fields.Many2one("res.users", string="Client", required=True)
    new_pin = fields.Char(string="Nouveau PIN", required=True)

    def action_confirm(self):
        self.ensure_one()
        if not PIN_RE.match(self.new_pin or ""):
            raise UserError("Le PIN doit contenir entre 6 et 12 chiffres.")
        self.user_id._set_pin(self.new_pin)
