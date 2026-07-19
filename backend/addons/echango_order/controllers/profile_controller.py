import re

from odoo import http
from odoo.exceptions import AccessDenied
from odoo.http import request

PIN_RE = re.compile(r"^\d{6,12}$")


class EchangoProfileController(http.Controller):
    """F10 — profil utilisateur. `res.partner`/`res.users` sont en lecture
    seule pour le portail (vérifié contre le code source de `base` :
    `access_res_partner_portal` 1,0,0,0) — toute écriture passe par ce
    contrôleur en `sudo()`. Pas de vérification de propriétaire explicite
    à faire : on n'agit jamais que sur `request.env.user`/son partenaire.
    """

    @http.route("/echango/profile", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def get_profile(self, **kw):
        partner = request.env.user.partner_id
        return {
            "name": partner.name,
            "phone": partner.phone,
            "lang": partner.lang,
            "latitude": partner.partner_latitude,
            "longitude": partner.partner_longitude,
        }

    @http.route("/echango/profile/update_name", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def update_name(self, name=None, **kw):
        name = (name or "").strip()
        if not name:
            return {"error": "validation.required"}
        request.env.user.partner_id.sudo().write({"name": name})
        return {"success": True}

    @http.route("/echango/profile/change_pin", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def change_pin(self, current_pin=None, new_pin=None, **kw):
        if not new_pin or not PIN_RE.match(new_pin):
            return {"error": "validation.pin_format"}
        user = request.env.user
        try:
            # Réutilise _check_pin (F02) : une tentative avec un mauvais
            # PIN actuel compte aussi dans le délai anti brute-force, comme
            # pour la connexion.
            user._check_pin(current_pin or "")
        except AccessDenied:
            return {"error": "auth.invalid_credentials"}
        user._set_pin(new_pin)
        return {"success": True}
