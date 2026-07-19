from odoo import fields, http
from odoo.http import request

from .cart_controller import EchangoCartController


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
    def check_zone(self, city=None, zip_code=None, **kw):
        city = (city or "").strip()
        zip_code = (zip_code or "").strip()
        if not city and not zip_code:
            return {"covered": False}
        zone = request.env["x_delivery_zone"].sudo().search([
            "|", ("city", "=ilike", city), ("zip_code", "=", zip_code),
        ], limit=1)
        return {"covered": bool(zone)}

    @http.route("/echango/checkout/apply_promo", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
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

    @http.route("/echango/checkout/confirm", type="jsonrpc", auth="user", methods=["POST"], csrf=False)
    def confirm(self, reception_mode=None, slot_start=None, street=None, city=None,
                zip_code=None, notes=None, **kw):
        if reception_mode not in ("home_delivery", "pickup"):
            return {"error": "validation.required"}

        partner = request.env.user.partner_id
        order = request.env["sale.order"].sudo().search(
            [("partner_id", "=", partner.id), ("state", "=", "draft")],
            order="id desc", limit=1,
        )
        if not order or not order.order_line:
            return {"error": "not_found"}

        vals = {"x_reception_mode": reception_mode}
        if slot_start:
            vals["x_creneau"] = slot_start

        if reception_mode == "home_delivery":
            zone = request.env["x_delivery_zone"].sudo().search([
                "|", ("city", "=ilike", (city or "").strip()), ("zip_code", "=", (zip_code or "").strip()),
            ], limit=1)
            if not zone:
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

        return {
            "order_ref": order.name,
            "amount_total": order.amount_total,
            "reception_mode": order.x_reception_mode,
            "slot_start": order.x_creneau.isoformat() if order.x_creneau else None,
        }
