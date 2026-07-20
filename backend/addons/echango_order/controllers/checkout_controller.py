from odoo import fields, http
from odoo.http import request

from .cart_controller import EchangoCartController
from .session_utils import require_fresh_session


def _resolve_promo_error(order, code):
    """F15 — reproduit les vérifications internes de `sale.order.
    _try_apply_code` (module standard `sale_loyalty`, vérifié contre le
    code source Odoo 19) pour retourner nos propres codes `AppError`
    stables, plutôt que de dépendre du texte des messages d'erreur
    internes à Odoo (traduit selon la langue du client, donc pas fiable
    comme code — même leçon que `AccessDenied` en F02). Retourne `None` si
    le code semble valide ; `_try_apply_code` reste la vérification
    définitive, appelée juste après par l'appelant.
    """
    domain = order._get_trigger_domain() + [("mode", "=", "with_code"), ("code", "=", code)]
    rule = request.env["loyalty.rule"].sudo().search(domain)
    if rule:
        program = rule.program_id
    else:
        coupon = request.env["loyalty.card"].sudo().search([("code", "=", code)], limit=1)
        if not coupon or not coupon.program_id.active or not coupon.program_id.reward_ids:
            return "promo.invalid"
        if coupon.expiration_date and coupon.expiration_date < fields.Datetime.now():
            return "promo.expired"
        if coupon.points < min(coupon.program_id.reward_ids.mapped("required_points")):
            return "promo.already_used"
        program = coupon.program_id

    if not program or not program.active:
        return "promo.invalid"
    if program.program_type in ("loyalty", "ewallet"):
        return "promo.invalid"
    if program.limit_usage and program.total_order_count >= program.max_usage:
        return "promo.expired"
    return None


class EchangoCheckoutController(http.Controller):
    """F07 — mode de réception, zone de livraison, créneau, confirmation.

    `x_delivery_zone` n'est pas exposé au portail via `call_kw` (voir
    `models/delivery_zone.py`) : la vérification d'appartenance se fait
    ici, en `sudo()`.
    """

    @http.route("/echango/checkout/check_zone", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def check_zone(self, city=None, zip_code=None, **kw):
        city = (city or "").strip()
        zip_code = (zip_code or "").strip()
        if not city and not zip_code:
            return {"covered": False}
        zone = request.env["x_delivery_zone"].sudo().search([
            "|", ("city", "=ilike", city), ("zip_code", "=", zip_code),
        ], limit=1)
        return {"covered": bool(zone)}

    @http.route("/echango/checkout/timeslots", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def timeslots(self, reception_mode=None, slots=None, **kw):
        """F07 — capacité des créneaux ("créneau complet grisé", specs QA).
        `slots` = créneaux candidats déjà générés côté client
        (`utils/timeslots.dart`, seule source de vérité pour les horaires
        proposés) : une liste de `{"start": <datetime Odoo, déjà en UTC via
        formatOdooDatetime>, "hour": <heure locale affichée, 0-23>}`. La
        capacité (`x_timeslot_capacity.hour`) est exprimée en heure locale
        (celle que voit un utilisateur back-office, "10h"/"14h"/"16h"...),
        pas en UTC — d'où l'heure locale transmise séparément plutôt que
        déduite de `start`, qui a pu changer de fuseau à la conversion
        (cf. status-V1.md § fuseau horaire x_creneau). Pas de capacité
        configurée pour une heure donnée -> jamais complet (comportement
        par défaut inchangé).
        """
        if reception_mode not in ("home_delivery", "pickup") or not slots:
            return {"full": []}
        full = [
            item["start"] for item in slots
            if item.get("start") and self._slot_is_full(reception_mode, item.get("hour"), item["start"])
        ]
        return {"full": full}

    @staticmethod
    def _slot_is_full(reception_mode, hour, start):
        """Partagé entre `timeslots()` (grisage côté app) et `confirm()`
        (vérification qui compte réellement, côté serveur — même logique
        que `x_verification_state` ci-dessous). `hour` = heure locale
        (voir docstring de `timeslots`), `start` = valeur de `x_creneau`
        au format Odoo (déjà en UTC)."""
        capacity = request.env["x_timeslot_capacity"].sudo().search([
            ("reception_mode", "=", reception_mode), ("hour", "=", hour),
        ], limit=1)
        if not capacity:
            return False
        count = request.env["sale.order"].sudo().search_count([
            ("x_reception_mode", "=", reception_mode),
            ("x_creneau", "=", start),
            ("state", "!=", "cancel"),
        ])
        return count >= capacity.max_orders

    @http.route("/echango/checkout/apply_promo", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def apply_promo(self, code=None, **kw):
        code = (code or "").strip()
        if not code:
            return {"error": "validation.required"}

        order = EchangoCartController()._cart_order()
        if not order or not order.order_line:
            return {"error": "not_found"}

        # Un seul code promo par commande (specs QA) : on retire
        # l'éventuel code déjà appliqué avant d'en essayer un nouveau,
        # plutôt que de les empiler.
        if order.applied_coupon_ids or order.code_enabled_rule_ids:
            order.sudo().write({
                "applied_coupon_ids": [(5, 0, 0)],
                "code_enabled_rule_ids": [(5, 0, 0)],
            })
            order.sudo()._update_programs_and_rewards()

        error_code = _resolve_promo_error(order, code)
        if error_code:
            return {"error": error_code}

        result = order.sudo()._try_apply_code(code)
        if "error" in result:
            return {"error": "promo.invalid"}

        # `result` = `_get_claimable_rewards()` : {coupon: récompenses}.
        # Un programme "code promo" correctement configuré (une seule
        # récompense) n'a qu'une entrée — on l'applique directement, pas
        # d'écran de choix de récompense (hors scope du wireframe F15).
        for coupon, rewards in result.items():
            if rewards:
                apply_result = order.sudo()._apply_program_reward(rewards[0], coupon)
                if "error" in apply_result:
                    return {"error": "promo.invalid"}
            break

        return EchangoCartController()._cart_payload(order)

    @staticmethod
    def _zone_covers(city, zip_code):
        return bool(request.env["x_delivery_zone"].sudo().search([
            "|", ("city", "=ilike", (city or "").strip()), ("zip_code", "=", (zip_code or "").strip()),
        ], limit=1))

    @http.route("/echango/checkout/confirm", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    @require_fresh_session
    def confirm(self, reception_mode=None, slot_start=None, slot_hour=None, address_id=None, street=None,
                city=None, zip_code=None, notes=None, **kw):
        if reception_mode not in ("home_delivery", "pickup"):
            return {"error": "validation.required"}
        # Capacité des créneaux — la vérification qui compte réellement
        # est ici, pas seulement le grisage côté app (`timeslots()`) qu'un
        # appel direct à cet endpoint contournerait sinon.
        if slot_start and self._slot_is_full(reception_mode, slot_hour, slot_start):
            return {"error": "checkout.slot_full"}

        partner = request.env.user.partner_id
        # Qualité clients — un compte pas encore validé par un modérateur
        # (ou rejeté) ne peut pas passer commande. Vérifié ici, au moment
        # de la confirmation réelle (la seule action qui compte vraiment),
        # pas à la création du panier ni pendant le parcours checkout.
        if partner.x_verification_state == "pending":
            return {"error": "auth.account_pending_verification"}
        if partner.x_verification_state == "rejected":
            return {"error": "auth.account_rejected"}

        order = request.env["sale.order"].sudo().search(
            [("partner_id", "=", partner.id), ("state", "=", "draft")],
            order="id desc", limit=1,
        )
        if not order or not order.order_line:
            return {"error": "not_found"}
        # Stock revérifié à la confirmation, pas seulement à l'ajout au
        # panier (`cart_controller.add`) : un panier laissé en brouillon
        # plusieurs jours peut être confirmé alors qu'un produit est
        # entre-temps devenu indisponible — même principe que la
        # revérification de la capacité des créneaux ci-dessus (trouvé à
        # l'audit technique du 2026-07-19). Ne bloque plus sur un message
        # générique dès la première ligne en rupture (décision produit
        # 2026-07, remplace F17) : toutes les lignes indisponibles sont
        # remontées d'un coup, avec pour chacune les produits de
        # substitution pré-définis par l'admin (`x_substitute_product_ids`)
        # — c'est au client de remplacer ou de supprimer chaque ligne
        # (jamais le préparateur), voir `mobile/lib/screens/checkout/
        # checkout_resolve_unavailable_screen.dart`.
        unavailable_lines = []
        for line in order.order_line.filtered(lambda l: not l.is_reward_line):
            template = line.product_id.product_tmpl_id
            if template.qty_available <= 0:
                substitutes = template.x_substitute_product_ids.filtered(
                    lambda t: t.sale_ok and t.qty_available > 0
                )
                unavailable_lines.append({
                    "line_id": line.id,
                    "product_name": line.product_id.display_name,
                    "qty": line.product_uom_qty,
                    "substitutes": [
                        {
                            "id": t.id,
                            "name": t.display_name,
                            "list_price": t.list_price,
                            "image_128": t.image_128.decode() if t.image_128 else None,
                        }
                        for t in substitutes
                    ],
                })
        if unavailable_lines:
            return {"error": "cart.unavailable_products", "unavailable_lines": unavailable_lines}

        vals = {"x_reception_mode": reception_mode}
        if slot_start:
            vals["x_creneau"] = slot_start

        if reception_mode == "home_delivery":
            if address_id:
                # F10 — adresse sauvegardée (`res.partner` enfant type
                # 'delivery') choisie au checkout plutôt qu'une adresse
                # ressaisie à chaque commande (cf. status-V1.md § Points
                # de vigilance). Réutilisée telle quelle comme
                # partner_shipping_id, pas de recréation de contact.
                shipping = request.env["res.partner"].sudo().search([
                    ("id", "=", address_id), ("parent_id", "=", partner.id), ("type", "=", "delivery"),
                ], limit=1)
                if not shipping:
                    return {"error": "not_found"}
                if not self._zone_covers(shipping.city, shipping.zip):
                    return {"error": "checkout.out_of_delivery_zone"}
            else:
                if not self._zone_covers(city, zip_code):
                    return {"error": "checkout.out_of_delivery_zone"}
                shipping = request.env["res.partner"].sudo().create({
                    "name": partner.name,
                    "parent_id": partner.id,
                    "type": "delivery",
                    "street": street,
                    "city": city,
                    "zip": zip_code,
                    "comment": notes,
                })
            vals["partner_shipping_id"] = shipping.id

        order.sudo().write(vals)
        order.sudo().action_confirm()
        self._seed_favorites(partner, order)

        return {
            "order_ref": order.name,
            "amount_total": order.amount_total,
            "reception_mode": order.x_reception_mode,
            "slot_start": order.x_creneau.isoformat() if order.x_creneau else None,
        }

    def _seed_favorites(self, partner, order):
        """Liste de favoris (`x_product_favorite`) initialisée
        automatiquement par les produits achetés — dédupliqué, le client
        peut ensuite en retirer/ajouter manuellement
        (`controllers/favorites_controller.py`)."""
        favorite = request.env["x_product_favorite"].sudo()
        existing = set(favorite.search([("partner_id", "=", partner.id)]).product_tmpl_id.ids)
        for line in order.order_line.filtered(lambda l: not l.is_reward_line):
            tmpl_id = line.product_id.product_tmpl_id.id
            if tmpl_id not in existing:
                favorite.create({"partner_id": partner.id, "product_tmpl_id": tmpl_id})
                existing.add(tmpl_id)
