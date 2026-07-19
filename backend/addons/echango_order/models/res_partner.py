from odoo import fields, models


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
