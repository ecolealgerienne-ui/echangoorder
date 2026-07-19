from datetime import timedelta

from werkzeug.security import check_password_hash, generate_password_hash

from odoo import fields, models
from odoo.exceptions import AccessDenied

# Délai progressif anti brute-force (CLAUDE.md § Exigences transversales) :
# chaque échec verrouille le compte quelques secondes de plus (1/2/4/8s),
# le 5e échec déclenche un blocage plus long. Implémenté comme une fenêtre
# "locked_until" vérifiée à la volée plutôt qu'un time.sleep() qui bloquerait
# un worker Odoo.
PIN_BACKOFF_SECONDS = {1: 1, 2: 2, 3: 4, 4: 8}
PIN_LOCKOUT_SECONDS = 15 * 60  # 5e échec : à valider avec le PO (cf. status-V1.md §4)


class ResUsers(models.Model):
    _inherit = "res.users"

    x_pin = fields.Char(string="PIN (haché)", copy=False, groups="base.group_system")
    x_pin_fail_count = fields.Integer(string="Échecs PIN", default=0, copy=False, groups="base.group_system")
    x_pin_locked_until = fields.Datetime(string="PIN bloqué jusqu'à", copy=False, groups="base.group_system")

    def _set_pin(self, pin):
        self.ensure_one()
        self.sudo().write({
            "x_pin": generate_password_hash(pin),
            "x_pin_fail_count": 0,
            "x_pin_locked_until": False,
        })

    def _check_pin(self, pin):
        self.ensure_one()
        now = fields.Datetime.now()
        if self.x_pin_locked_until and self.x_pin_locked_until > now:
            raise AccessDenied("auth.account_locked")
        if not self.x_pin or not check_password_hash(self.x_pin, pin):
            fail_count = self.x_pin_fail_count + 1
            delay = PIN_LOCKOUT_SECONDS if fail_count >= 5 else PIN_BACKOFF_SECONDS.get(fail_count, 8)
            self.sudo().write({
                "x_pin_fail_count": fail_count,
                "x_pin_locked_until": now + timedelta(seconds=delay),
            })
            raise AccessDenied("auth.invalid_credentials")
        self.sudo().write({"x_pin_fail_count": 0, "x_pin_locked_until": False})

    def _check_credentials(self, credential, env):
        if credential.get("type") == "pin":
            self._check_pin(credential.get("password") or "")
            return {"uid": self.id}
        return super()._check_credentials(credential, env)
