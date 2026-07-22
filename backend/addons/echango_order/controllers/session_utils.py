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

# Bug trouvé en test réel (2026-07-22) : deux appels /echango/* quasi
# simultanés pour le même utilisateur (ex. getStock/getPromotions
# parallélisés, cf. status-V1.md § Audit de performance) écrivaient tous
# les deux x_last_activity sur la même ligne res_users au même instant —
# `ERROR: could not serialize access due to concurrent update` côté
# Postgres. Throttle de l'écriture (déjà identifié comme piste
# d'optimisation dans status-V1.md, "à valider avant de le faire" —
# validé avec l'utilisateur suite à ce bug) : n'écrit que si la dernière
# valeur connue date de plus de quelques minutes, largement suffisant
# face à une fenêtre d'expiration de 24h — imprécision négligeable,
# réduit fortement (sans l'éliminer totalement : deux tout premiers
# appels rigoureusement simultanés peuvent encore tous les deux décider
# d'écrire) la fréquence des écritures concurrentes sur la même ligne.
ACTIVITY_WRITE_THROTTLE = timedelta(minutes=2)


def require_fresh_session(func):
    """Décorateur pour les méthodes de contrôleur `auth="user"` : renvoie
    `{"error": "auth.session_expired"}` (déjà mappé côté Flutter vers
    AppError.authSessionExpired, qui déclenche la ré-authentification) si
    plus de 24h se sont écoulées depuis le dernier appel réussi, sinon
    laisse passer et met à jour x_last_activity (au plus une fois par
    ACTIVITY_WRITE_THROTTLE, voir commentaire ci-dessus)."""

    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        user = request.env.user
        now = fields.Datetime.now()
        last = user.x_last_activity
        if last and (now - last) > SESSION_INACTIVITY_LIMIT:
            return {"error": "auth.session_expired"}
        result = func(self, *args, **kwargs)
        if not last or (now - last) > ACTIVITY_WRITE_THROTTLE:
            user.sudo().write({"x_last_activity": now})
        return result

    return wrapper
