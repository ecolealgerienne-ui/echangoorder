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

    def _address_payload(self, address):
        return {
            "id": address.id,
            "name": address.name,
            "street": address.street,
            "city": address.city,
            "zip": address.zip,
            "comment": address.comment,
            "favorite": address.x_adresse_favorite,
        }

    def _owned_address(self, address_id):
        partner = request.env.user.partner_id
        return request.env["res.partner"].sudo().search([
            ("id", "=", address_id), ("parent_id", "=", partner.id), ("type", "=", "delivery"),
        ], limit=1)

    def _unset_other_favorites(self, partner, exclude_id=None):
        domain = [
            ("parent_id", "=", partner.id), ("type", "=", "delivery"), ("x_adresse_favorite", "=", True),
        ]
        if exclude_id:
            domain.append(("id", "!=", exclude_id))
        request.env["res.partner"].sudo().search(domain).write({"x_adresse_favorite": False})

    @http.route("/echango/profile/addresses", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def list_addresses(self, **kw):
        partner = request.env.user.partner_id
        addresses = request.env["res.partner"].sudo().search([
            ("parent_id", "=", partner.id), ("type", "=", "delivery"),
        ])
        return {"addresses": [self._address_payload(a) for a in addresses]}

    @http.route("/echango/profile/addresses/add", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def add_address(self, name=None, street=None, city=None, zip_code=None, comment=None, favorite=False, **kw):
        partner = request.env.user.partner_id
        if not (street or "").strip() or not (city or "").strip():
            return {"error": "validation.required"}
        if favorite:
            self._unset_other_favorites(partner)
        address = request.env["res.partner"].sudo().create({
            "name": (name or partner.name),
            "parent_id": partner.id,
            "type": "delivery",
            "street": street,
            "city": city,
            "zip": zip_code,
            "comment": comment,
            "x_adresse_favorite": bool(favorite),
        })
        return self._address_payload(address)

    @http.route("/echango/profile/addresses/update", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def update_address(self, address_id=None, name=None, street=None, city=None, zip_code=None, comment=None,
                        favorite=None, **kw):
        address = self._owned_address(address_id)
        if not address:
            return {"error": "not_found"}
        if not (street or "").strip() or not (city or "").strip():
            return {"error": "validation.required"}
        if favorite:
            self._unset_other_favorites(address.parent_id, exclude_id=address.id)
        vals = {
            "name": name or address.name,
            "street": street,
            "city": city,
            "zip": zip_code,
            "comment": comment,
        }
        if favorite is not None:
            vals["x_adresse_favorite"] = bool(favorite)
        address.sudo().write(vals)
        return self._address_payload(address)

    @http.route("/echango/profile/addresses/remove", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def remove_address(self, address_id=None, **kw):
        address = self._owned_address(address_id)
        if not address:
            return {"error": "not_found"}
        address.sudo().unlink()
        return {"success": True}
