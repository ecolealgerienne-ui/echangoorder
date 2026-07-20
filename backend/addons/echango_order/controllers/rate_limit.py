import functools

from odoo.http import request


def rate_limited(action, limit, window_minutes):
    """Anti-abus (CLAUDE.md § Exigences transversales : "endpoints publics
    filtrés + rate limités") pour les endpoints `auth="public"` — pas de
    session/utilisateur identifié, la clé est donc l'adresse IP (voir
    models/rate_limit.py pour le détail du mécanisme). Renvoie
    `{"error": "rate_limited"}` au-delà de `limit` appels par fenêtre de
    `window_minutes`."""

    def decorator(func):
        @functools.wraps(func)
        def wrapper(self, *args, **kwargs):
            ip = request.httprequest.remote_addr or "unknown"
            key = f"{action}:{ip}"
            if request.env["x_rate_limit"].sudo()._hit(key, limit, window_minutes):
                return {"error": "rate_limited"}
            return func(self, *args, **kwargs)

        return wrapper

    return decorator
