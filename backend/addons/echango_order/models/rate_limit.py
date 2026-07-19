from datetime import timedelta

from odoo import fields, models


class RateLimit(models.Model):
    """Anti-abus sur les endpoints publics (CLAUDE.md § Exigences
    transversales : "endpoints publics filtrés + rate limités"). Odoo n'a
    pas de mécanisme de rate limiting HTTP intégré pour des contrôleurs
    custom — compteur à fenêtre fixe par clé (typiquement `action:ip`),
    justifié. Ne remplace pas un WAF/reverse proxy en production (pas
    encore déployé, voir status-V1.md § HTTPS/TLS), défense en profondeur
    applicative en attendant. Utilisé uniquement en `sudo()` depuis
    `controllers/rate_limit.py`, jamais exposé au portail.
    """

    _name = "x_rate_limit"
    _description = "Compteur anti-abus (fenêtre fixe) — endpoints publics Echango Order"

    key = fields.Char(required=True, index=True)
    window_start = fields.Datetime(required=True)
    count = fields.Integer(default=0)

    def _hit(self, key, limit, window_minutes):
        """Incrémente le compteur pour `key`, réinitialise la fenêtre si
        elle est expirée. Renvoie True si `limit` est dépassée (appel à
        bloquer)."""
        now = fields.Datetime.now()
        record = self.search([("key", "=", key)], limit=1)
        if not record or (now - record.window_start) > timedelta(minutes=window_minutes):
            if record:
                record.write({"window_start": now, "count": 1})
            else:
                self.create({"key": key, "window_start": now, "count": 1})
            return False
        record.write({"count": record.count + 1})
        return record.count > limit

    def _gc(self):
        """Purge les compteurs de plus d'un jour — appelé par un ir.cron
        quotidien (data/rate_limit_data.xml). Toutes les fenêtres réelles
        se comptent en minutes, un délai d'un jour est largement
        suffisant pour ne jamais purger un compteur encore actif."""
        stale = self.search([("window_start", "<", fields.Datetime.now() - timedelta(days=1))])
        stale.unlink()
