import re

from odoo import http
from odoo.exceptions import AccessDenied
from odoo.http import request

PIN_RE = re.compile(r"^\d{6,12}$")


class EchangoAuthController(http.Controller):
    """Inscription et connexion téléphone+PIN pour l'app mobile (F02).

    Une fois la session ouverte ici, le reste des appels passe par le
    /web/dataset/call_kw standard d'Odoo (utilisateur portail, cf. CLAUDE.md
    § Principe architecture Odoo) — ce contrôleur ne gère que ce qu'Odoo
    n'a pas nativement : la connexion par téléphone+PIN.
    """

    @http.route("/echango/auth/register", type="json", auth="public", methods=["POST"], csrf=False)
    def register(self, phone=None, pin=None, name=None, lang=None, **kw):
        phone = (phone or "").strip()
        pin = (pin or "").strip()
        if not phone:
            return {"error": "validation.phone_required"}
        if not PIN_RE.match(pin):
            return {"error": "validation.pin_format"}

        users = request.env["res.users"].sudo()
        if users.search_count([("login", "=", phone)]):
            return {"error": "auth.phone_already_registered"}

        portal_group = request.env.ref("base.group_portal")
        partner = request.env["res.partner"].sudo().create({
            "name": name or phone,
            "mobile": phone,
            "lang": lang or request.env.company.partner_id.lang or "fr_FR",
        })
        user = users.create({
            "name": partner.name,
            "login": phone,
            "partner_id": partner.id,
            "groups_id": [(6, 0, [portal_group.id])],
            "active": True,
        })
        user._set_pin(pin)
        return {"success": True, "user_id": user.id}

    @http.route("/echango/auth/login", type="json", auth="public", methods=["POST"], csrf=False)
    def login(self, phone=None, pin=None, **kw):
        phone = (phone or "").strip()
        pin = (pin or "").strip()
        if not phone or not pin:
            return {"error": "validation.required"}

        credential = {"login": phone, "password": pin, "type": "pin"}
        try:
            auth_info = request.session.authenticate(request.db, credential)
        except AccessDenied as exc:
            return {"error": str(exc) or "auth.invalid_credentials"}

        uid = auth_info.get("uid") if isinstance(auth_info, dict) else request.session.uid
        return {"success": True, "uid": uid}
