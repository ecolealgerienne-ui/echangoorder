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

    _key_uniq = models.Constraint(
        "unique(key)",
        "Une seule ligne de compteur par clé.",
    )

    def _hit(self, key, limit, window_minutes):
        """Incrémente le compteur pour `key`, réinitialise la fenêtre si
        elle est expirée. Renvoie True si `limit` est dépassée (appel à
        bloquer).

        `SELECT ... FOR UPDATE` verrouille explicitement la ligne avant
        lecture/écriture — sans ça, deux requêtes concurrentes sur la même
        clé peuvent toutes deux lire le même compteur avant qu'aucune
        n'ait écrit sa mise à jour ("lost update" classique en isolation
        READ COMMITTED Postgres, trouvé à l'audit sécurité du
        2026-07-19) : la limite serait alors contournable en envoyant des
        appels en rafale plutôt qu'en séquence. Valeurs lues directement
        en SQL (pas via le cache ORM) pour être sûr qu'elles reflètent
        l'état réel sous le verrou.
        """
        now = fields.Datetime.now()
        self.env.cr.execute(
            "SELECT id, window_start, count FROM x_rate_limit WHERE key = %s FOR UPDATE", (key,),
        )
        row = self.env.cr.fetchone()
        if row:
            record_id, window_start, count = row
            if (now - window_start) > timedelta(minutes=window_minutes):
                self.browse(record_id).write({"window_start": now, "count": 1})
                return False
            new_count = count + 1
            self.browse(record_id).write({"count": new_count})
            return new_count > limit

        # Pas de ligne existante : la création elle-même peut entrer en
        # conflit avec une autre requête concurrente créant la même clé au
        # même instant (contrainte unique ci-dessus) — repli sur une mise
        # à jour dans ce cas plutôt que de laisser l'erreur remonter.
        try:
            with self.env.cr.savepoint():
                self.create({"key": key, "window_start": now, "count": 1})
            return False
        except Exception:
            self.env.cr.execute(
                "SELECT id, count FROM x_rate_limit WHERE key = %s FOR UPDATE", (key,),
            )
            row = self.env.cr.fetchone()
            if not row:
                return False
            record_id, count = row
            new_count = count + 1
            self.browse(record_id).write({"count": new_count})
            return new_count > limit

    def _gc(self):
        """Purge les compteurs de plus d'un jour — appelé par un ir.cron
        quotidien (data/rate_limit_data.xml). Toutes les fenêtres réelles
        se comptent en minutes, un délai d'un jour est largement
        suffisant pour ne jamais purger un compteur encore actif."""
        stale = self.search([("window_start", "<", fields.Datetime.now() - timedelta(days=1))])
        stale.unlink()
