import re

from odoo import fields, http
from odoo.exceptions import AccessDenied
from odoo.http import request

from .rate_limit import rate_limited

PIN_RE = re.compile(r"^\d{6,12}$")


class EchangoAuthController(http.Controller):
    """Inscription et connexion téléphone+PIN pour l'app mobile (F02).

    Une fois la session ouverte ici, le reste des appels passe par le
    /web/dataset/call_kw standard d'Odoo (utilisateur portail, cf. CLAUDE.md
    § Principe architecture Odoo) — ce contrôleur ne gère que ce qu'Odoo
    n'a pas nativement : la connexion par téléphone+PIN.
    """

    @http.route("/echango/auth/register", type="jsonrpc", auth="public", methods=["POST"], csrf=False)
    @rate_limited("auth.register", limit=5, window_minutes=60)
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

        # N'assigner que des codes de langue réellement installés/actifs :
        # écrire un code non installé (ex: "fr_FR" si le pack de langue
        # française n'a pas été chargé dans cette base) fait planter plus
        # tard des mécanismes internes (notifications sur sale.order...)
        # avec un "Invalid language code" peu explicite. Odoo se débrouille
        # très bien avec lang=False (repli automatique, cf. odoo.tools.get_lang).
        installed_langs = dict(request.env["res.lang"].sudo().get_installed())
        requested_lang = lang or "fr_FR"
        partner_lang = requested_lang if requested_lang in installed_langs else False

        portal_group = request.env.ref("base.group_portal")
        partner = request.env["res.partner"].sudo().create({
            "name": name or phone,
            "phone": phone,
            "lang": partner_lang,
            # Qualité clients — chaque NOUVEAU compte démarre "pending" (le
            # champ par défaut à "verified" pour ne pas affecter les
            # partenaires déjà en base) : un modérateur doit le valider en
            # back-office avant que le client puisse passer commande, voir
            # controllers/checkout_controller.py.
            "x_verification_state": "pending",
        })
        partner._notify_verification_pending()
        user = users.create({
            "name": partner.name,
            "login": phone,
            "partner_id": partner.id,
            "group_ids": [(6, 0, [portal_group.id])],
            "active": True,
        })
        user._set_pin(pin)
        return {"success": True, "user_id": user.id}

    @http.route("/echango/auth/login", type="jsonrpc", auth="public", methods=["POST"], csrf=False)
    @rate_limited("auth.login", limit=10, window_minutes=5)
    def login(self, phone=None, pin=None, **kw):
        phone = (phone or "").strip()
        pin = (pin or "").strip()
        if not phone or not pin:
            return {"error": "validation.required"}

        # Rate limiting par IP (décorateur ci-dessus) contournable en
        # multipliant les IP (proxy/VPN) pour cibler un seul numéro —
        # limite supplémentaire par numéro de téléphone, plus permissive
        # en apparence mais qui ne peut pas être diluée sur plusieurs IP,
        # pour ralentir ce cas précis (trouvé à l'audit sécurité du
        # 2026-07-19 : les codes d'erreur distincts account_locked/
        # invalid_credentials permettent aussi de deviner si un numéro
        # est inscrit — non résolu ici, dégraderait l'UX sans réel
        # bénéfice contre un attaquant déterminé, voir status-V1.md).
        if request.env["x_rate_limit"].sudo()._hit(f"auth.login.phone:{phone}", 10, 15):
            return {"error": "rate_limited"}

        # Odoo's AccessDenied écrase volontairement son message par "Access
        # Denied" (anti fuite d'info) : impossible d'y lire un code d'erreur
        # après coup. On vérifie donc l'état de verrouillage nous-mêmes avant
        # d'appeler authenticate(), plutôt que d'inspecter l'exception.
        user = request.env["res.users"].sudo().search([("login", "=", phone)], limit=1)
        if user.x_pin_locked_until and user.x_pin_locked_until > fields.Datetime.now():
            return {"error": "auth.account_locked"}

        credential = {"login": phone, "password": pin, "type": "pin"}
        try:
            auth_info = request.session.authenticate(request.env, credential)
        except AccessDenied:
            return {"error": "auth.invalid_credentials"}

        uid = auth_info.get("uid") if isinstance(auth_info, dict) else request.session.uid
        # Point de départ de la politique "24h d'inactivité" (voir
        # controllers/session_utils.py) : sans ça, x_last_activity reste
        # vide jusqu'au premier appel à un endpoint /echango/* décoré,
        # laissant une fenêtre où l'expiration n'est pas encore vérifiée.
        request.env["res.users"].sudo().browse(uid).write({"x_last_activity": fields.Datetime.now()})
        return {"success": True, "uid": uid}

    @http.route("/echango/auth/request_pin_reset", type="jsonrpc", auth="public", methods=["POST"], csrf=False)
    @rate_limited("auth.request_pin_reset", limit=5, window_minutes=60)
    def request_pin_reset(self, phone=None, **kw):
        """F02 — "PIN oublié" : aucun fournisseur SMS choisi (cf.
        status-V1.md), la demande crée une activité pour un modérateur
        back-office (voir res_partner._notify_pin_reset_requested), qui
        recontacte le client par téléphone. Réponse toujours générique
        (`{"success": True}`), que le numéro existe ou non — sinon cet
        endpoint deviendrait un oracle pour savoir si un numéro de
        téléphone est inscrit (énumération de comptes).
        """
        phone = (phone or "").strip()
        if phone:
            user = request.env["res.users"].sudo().search([("login", "=", phone)], limit=1)
            if user:
                user.partner_id._notify_pin_reset_requested()
        return {"success": True}
