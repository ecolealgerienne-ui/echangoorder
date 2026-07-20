import functools
from datetime import timedelta

from odoo import fields
from odoo.http import request

# Session expirée après 24h d'inactivité (CLAUDE.md § Exigences
# transversales). Odoo ne propose pas nativement de politique d'expiration
# applicative par inactivité (seulement une expiration du fichier de
# session, sur une durée qui dépend de sa configuration par défaut, non
# vérifiable dans ce sandbox sans Docker) : x_last_activity (res.users)
# donne un contrôle explicite et testable, appliqué à tous les endpoints
# /echango/* qui exigent auth="user" (lecture ou écriture). Les lectures
# passant par le /web/dataset/call_kw standard (catalogue, historique...)
# restent hors de portée de ce décorateur, propre aux contrôleurs custom.
SESSION_INACTIVITY_LIMIT = timedelta(hours=24)


def require_fresh_session(func):
    """Décorateur pour les méthodes de contrôleur `auth="user"` : renvoie
    `{"error": "auth.session_expired"}` (déjà mappé côté Flutter vers
    AppError.authSessionExpired, qui déclenche la ré-authentification) si
    plus de 24h se sont écoulées depuis le dernier appel réussi, sinon
    laisse passer et met à jour x_last_activity."""

    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        user = request.env.user
        now = fields.Datetime.now()
        last = user.x_last_activity
        if last and (now - last) > SESSION_INACTIVITY_LIMIT:
            return {"error": "auth.session_expired"}
        result = func(self, *args, **kwargs)
        user.sudo().write({"x_last_activity": now})
        return result

    return wrapper
