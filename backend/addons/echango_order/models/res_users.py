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
    # Session expirée après 24h d'inactivité (CLAUDE.md § Exigences
    # transversales) : `login_date` (standard) n'est mis à jour qu'à la
    # connexion, pas à chaque appel — aucun équivalent standard pour un
    # horodatage de dernière activité API, champ custom justifié. Mis à
    # jour par require_fresh_session (controllers/session_utils.py) sur
    # chaque appel réussi aux endpoints /echango/*.
    x_last_activity = fields.Datetime(string="Dernière activité", copy=False)

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
        # Verrou explicite + lecture fraîche en SQL (pas le cache ORM,
        # déjà potentiellement peuplé par la vérification de blocage faite
        # avant authenticate() dans auth_controller.login) : sans ça, des
        # tentatives de PIN envoyées en parallèle peuvent toutes lire le
        # même x_pin_fail_count avant qu'aucune n'ait écrit sa mise à jour
        # ("lost update" classique en isolation READ COMMITTED Postgres),
        # affaiblissant le délai progressif anti brute-force (trouvé à
        # l'audit sécurité du 2026-07-19).
        self.env.cr.execute(
            "SELECT x_pin, x_pin_fail_count, x_pin_locked_until FROM res_users WHERE id = %s FOR UPDATE",
            (self.id,),
        )
        x_pin, fail_count, locked_until = self.env.cr.fetchone()
        if locked_until and locked_until > now:
            raise AccessDenied("auth.account_locked")
        if not x_pin or not check_password_hash(x_pin, pin):
            fail_count += 1
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
