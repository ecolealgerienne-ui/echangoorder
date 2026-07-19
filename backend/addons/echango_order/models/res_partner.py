from odoo import SUPERUSER_ID, fields, models


class ResPartner(models.Model):
    _inherit = "res.partner"

    x_adresse_favorite = fields.Boolean(
        string="Adresse favorite",
        help="F10 — une adresse de livraison (contact enfant type='delivery') "
        "peut être marquée favorite, une seule à la fois par client. Champ "
        "custom car Odoo n'a pas de notion de 'default address' parmi les "
        "contacts d'un partenaire — voir CLAUDE.md § Principe architecture Odoo.",
    )

    # Qualité clients — un modérateur côté back-office valide manuellement
    # chaque nouveau compte avant qu'il puisse passer commande (décision
    # produit : pas de service de géocodage en Phase 1, un humain tranche
    # à la place). Défaut à "verified" au niveau du champ pour ne pas
    # bloquer les partenaires/contacts déjà en base (adresses de livraison,
    # fournisseurs...) — seul `/echango/auth/register` positionne
    # explicitement "pending" sur un NOUVEAU compte client. Aucune notion
    # équivalente standard dans Odoo (pas de workflow de modération pour
    # un compte portail) — champ custom justifié.
    x_verification_state = fields.Selection(
        [("pending", "En attente"), ("verified", "Vérifié"), ("rejected", "Rejeté")],
        string="Vérification client",
        default="verified",
    )

    def action_verify_customer(self):
        self.write({"x_verification_state": "verified"})

    def action_reject_customer(self):
        self.write({"x_verification_state": "rejected"})

    def _get_verification_moderator(self):
        """Utilisateur back-office notifié quand un nouveau compte client
        passe en attente de validation. Pas de groupe de modération dédié
        (le menu "Clients à valider" est visible à tout utilisateur
        interne, cf. views/res_partner_views.xml) : on cible le premier
        utilisateur ayant les droits d'administration (`base.group_system`,
        déjà utilisé pour restreindre `x_pin` sur res.users), avec un repli
        sur l'utilisateur technique OdooBot (id=1, toujours présent) pour
        ne jamais échouer sur une base fraîchement installée sans admin
        dédié.
        """
        moderator = self.env["res.users"].sudo().search(
            [("groups_id", "=", self.env.ref("base.group_system").id)], limit=1, order="id",
        )
        return moderator or self.env["res.users"].browse(SUPERUSER_ID)

    def _notify_verification_pending(self):
        """Activité Odoo standard ("à faire") plutôt qu'un mécanisme de
        notification custom — visible dans le menu Activités du modérateur
        et dans le chatter de la fiche client. Pas d'email (aucun serveur
        SMTP configuré dans ce projet, cf. CLAUDE.md/status-V1.md), une
        activité back-office suffit puisqu'un modérateur consulte Odoo au
        quotidien."""
        self.ensure_one()
        moderator = self._get_verification_moderator()
        self.activity_schedule(
            "mail.mail_activity_data_todo",
            summary="Nouveau compte client à valider",
            note=f"{self.name} ({self.phone or 'téléphone non renseigné'}) vient de s'inscrire "
            "et attend une validation manuelle (menu Echango Order > Clients à valider).",
            user_id=moderator.id,
        )
