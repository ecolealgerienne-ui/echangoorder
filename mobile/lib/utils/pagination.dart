/// Taille de page par défaut des écrans de liste paginés (Accueil,
/// Catalogue, Recherche, Favoris, Historique commandes) — chargement à la
/// demande plutôt que tout afficher d'un coup.
///
/// Valeur volontairement abaissée à 4 pour tester le chargement à la
/// demande (bouton "Charger plus") sans dépendre de la taille du catalogue
/// de test — remettre à 50 une fois la fonctionnalité validée par
/// l'utilisateur.
const kListPageSize = 4;
