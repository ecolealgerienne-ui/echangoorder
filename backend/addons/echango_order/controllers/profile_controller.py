import re
import secrets

from odoo import http
from odoo.exceptions import AccessDenied
from odoo.http import request

from .session_utils import require_fresh_session

PIN_RE = re.compile(r"^\d{6,12}$")


class EchangoProfileController(http.Controller):
    """F10 — profil utilisateur. `res.partner`/`res.users` sont en lecture
    seule pour le portail (vérifié contre le code source de `base` :
    `access_res_partner_portal` 1,0,0,0) — toute écriture passe par ce
    contrôleur en `sudo()`. Pas de vérification de propriétaire explicite
    à faire : on n'agit jamais que sur `request.env.user`/son partenaire.
    """

    @http.route("/echango/profile", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def get_profile(self, **kw):
        partner = request.env.user.partner_id
        return {
            "name": partner.name,
            "phone": partner.phone,
            "lang": partner.lang,
        }

    @http.route("/echango/profile/update_name", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def update_name(self, name=None, **kw):
        name = (name or "").strip()
        if not name:
            return {"error": "validation.required"}
        request.env.user.partner_id.sudo().write({"name": name})
        return {"success": True}

    @http.route("/echango/profile/change_pin", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
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

    @http.route("/echango/profile/delete_account", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def delete_account(self, pin=None, **kw):
        user = request.env.user
        try:
            user._check_pin(pin or "")
        except AccessDenied:
            return {"error": "auth.invalid_credentials"}
        # Suppression logique standard Odoo (spec Expert Odoo) : `active`
        # existe déjà sur res.users (mixin standard), pas de champ custom.
        # Les données (partner, commandes) sont conservées, seul le compte
        # est désactivé — la SMS de confirmation (specs QA) est hors scope,
        # aucun fournisseur SMS choisi (cf. status-V1.md).
        #
        # `active=False` seul n'invalide pas forcément une session déjà
        # ouverte sur un autre appareil (le cookie de session reste valide
        # tant que le token de sécurité calculé par Odoo ne change pas).
        # On rend aussi le champ standard `password` inutilisable avec une
        # valeur aléatoire : ce champ fait partie des champs de sécurité
        # dont dépend le calcul du token de session côté Odoo (mécanisme
        # standard documenté : changer le mot de passe invalide les autres
        # sessions), donc l'écrire force l'expiration immédiate de toute
        # session existante, même si l'app n'utilise jamais l'authentification
        # par mot de passe (uniquement le PIN custom, cf. res_users.py).
        user.sudo().write({"active": False, "password": secrets.token_urlsafe(32)})
        return {"success": True}

    def _address_payload(self, address):
        return {
            "id": address.id,
            "name": address.name,
            "street": address.street,
            "city": address.city,
            # `zip`/`comment` ne sont jamais requis (contrairement à
            # street/city, validés avant création/mise à jour) — un Char
            # non renseigné vaut `False` côté ORM Odoo, pas `None`, donc
            # `False` une fois sérialisé en JSON. Normalisé ici : sinon
            # `as String?` côté Flutter (`addresses_screen.dart`,
            # `checkout_address_screen.dart`) plante dès qu'une adresse n'a
            # pas de code postal/note (trouvé par audit suite au bug
            # identique sur `x_delivery_status`).
            "zip": address.zip or None,
            "comment": address.comment or None,
            "favorite": address.x_adresse_favorite,
            # "Ma localisation" (ex-menu séparé) fusionnée dans les adresses :
            # champs standards du module base, déjà utilisés pour F10 avant
            # cette fusion — voir CLAUDE.md § Principe architecture Odoo.
            "latitude": address.partner_latitude,
            "longitude": address.partner_longitude,
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
    @require_fresh_session
    def list_addresses(self, **kw):
        partner = request.env.user.partner_id
        addresses = request.env["res.partner"].sudo().search([
            ("parent_id", "=", partner.id), ("type", "=", "delivery"),
        ])
        return {"addresses": [self._address_payload(a) for a in addresses]}

    @staticmethod
    def _coords_vals(latitude, longitude):
        """GPS optionnel sur une adresse — en plus de rue/ville/code postal,
        pas à leur place (pas de service de géocodage inverse choisi, donc
        pas moyen de remplir rue/ville depuis des coordonnées seules ; la
        vérification de zone de livraison continue de se baser sur
        ville/code postal, pas sur les coordonnées)."""
        try:
            return {"partner_latitude": float(latitude), "partner_longitude": float(longitude)}
        except (TypeError, ValueError):
            return {}

    @http.route("/echango/profile/addresses/add", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def add_address(self, name=None, street=None, city=None, zip_code=None, comment=None, favorite=False,
                     latitude=None, longitude=None, **kw):
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
            **self._coords_vals(latitude, longitude),
        })
        return self._address_payload(address)

    @http.route("/echango/profile/addresses/update", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def update_address(self, address_id=None, name=None, street=None, city=None, zip_code=None, comment=None,
                        favorite=None, latitude=None, longitude=None, **kw):
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
            **self._coords_vals(latitude, longitude),
        }
        if favorite is not None:
            vals["x_adresse_favorite"] = bool(favorite)
        address.sudo().write(vals)
        return self._address_payload(address)

    @http.route("/echango/profile/addresses/remove", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def remove_address(self, address_id=None, **kw):
        address = self._owned_address(address_id)
        if not address:
            return {"error": "not_found"}
        address.sudo().unlink()
        return {"success": True}
