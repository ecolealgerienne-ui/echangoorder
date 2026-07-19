from odoo import http
from odoo.http import request


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
