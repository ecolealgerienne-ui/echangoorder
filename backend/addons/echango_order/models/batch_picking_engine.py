"""Préparation groupée des commandes (batch picking + zone de tri) —
décision produit 2026-07, voir CLAUDE.md § Préparation groupée. Moteur de
clustering isolé en pur Python (aucune dépendance ORM) pour rester lisible
et vérifiable indépendamment du reste du module — `batch_picking_wizard.py`
se charge de la collecte des données Odoo et de la création des lots
réels, ce fichier ne fait que le calcul.

Conçu et challengé par une revue algorithmique dédiée avant codage (voir
CLAUDE.md § Préparation groupée pour le détail des 3 revues spécialisées) :
- seuil minimal de similarité comme condition d'arrêt (sinon le glouton
  regroupe des commandes sans aucun rapport dès que les contraintes de
  taille/charge le permettent) ;
- tie-break déterministe (ancienneté puis id) — un humain valide les
  suggestions, la reproductibilité d'un calcul à l'autre est nécessaire ;
- règle fair-play par dépassement de SLA (override dur, pas un score
  composite pondéré — plus explicable pour l'opérateur) ;
- similarité maintenue de façon incrémentale (compteur cumulé des produits
  du lot), pas recalculée depuis zéro à chaque candidat évalué.
"""

from collections import Counter


class CandidateOrder:
    """Représentation minimale d'une commande candidate au regroupement,
    indépendante de l'ORM Odoo — `batch_picking_wizard.py` construit ces
    objets à partir des `sale.order` réels."""

    def __init__(self, key, product_counts, line_count, qty_total, waiting_hours):
        self.key = key  # identifiant opaque (ex. sale.order.id), jamais interprété ici
        self.product_counts = product_counts  # Counter({product_tmpl_id: quantité})
        self.line_count = line_count
        self.qty_total = qty_total
        self.waiting_hours = waiting_hours  # ancienneté depuis confirmation, en heures


def jaccard(counts_a, counts_b):
    """Similarité de Jaccard sur les ENSEMBLES de produits (présence/absence
    par product_tmpl_id, pas pondéré par quantité) — même définition que
    dans les specs discutées avec l'utilisateur."""
    set_a, set_b = set(counts_a), set(counts_b)
    if not set_a and not set_b:
        return 0.0
    union = set_a | set_b
    if not union:
        return 0.0
    return len(set_a & set_b) / len(union)


def compute_batches(orders, max_orders, max_qty, max_lines, min_similarity, sla_hours):
    """Regroupe une liste de `CandidateOrder` (déjà filtrée en amont sur une
    fenêtre de temps compatible — un seul "bucket" par appel, le découpage
    en fenêtres est la responsabilité de l'appelant) en lots, suivant
    l'algorithme glouton discuté et challengé (voir docstring du module).

    Retourne une liste de lots, chaque lot étant une liste de `key` (dans
    l'ordre d'ajout : graine en premier). Une commande seule (aucun lot
    trouvé pour elle) apparaît comme un lot à un seul élément — le rôle de
    l'appelant/de l'opérateur est de décider quoi faire d'un lot de taille 1
    (le confirmer seul, ou attendre un prochain cycle).

    Contraintes dures respectées à chaque ajout : taille (max_orders),
    charge cumulée (max_qty, proxy = somme des quantités), nombre de lignes
    cumulé (max_lines, proxy du temps de traitement au poste de tri).
    """
    remaining = {o.key: o for o in orders}
    # Matrice de similarité précalculée une seule fois (O(N²), praticable à
    # l'échelle visée — confirmé par la revue algorithmique).
    keys = list(remaining)
    sim = {}
    for i, ka in enumerate(keys):
        for kb in keys[i + 1:]:
            s = jaccard(remaining[ka].product_counts, remaining[kb].product_counts)
            sim[(ka, kb)] = s
            sim[(kb, ka)] = s

    def similarity(key_a, key_b):
        if key_a == key_b:
            return 0.0
        return sim.get((key_a, key_b), 0.0)

    batches = []
    while remaining:
        # Règle fair-play (§4.4 des specs) : une commande qui dépasse le
        # seuil SLA devient graine forcée, indépendamment de son score de
        # similarité — override dur plutôt qu'un score composite, plus
        # explicable pour l'opérateur qui valide.
        overdue = [o for o in remaining.values() if o.waiting_hours >= sla_hours]
        if overdue:
            overdue.sort(key=lambda o: (-o.waiting_hours, o.key))
            seed_key = overdue[0].key
        else:
            # Graine = commande dont la somme des similarités avec les
            # AUTRES commandes ENCORE non affectées est la plus forte —
            # recalculée à chaque tour (pas une somme globale figée depuis
            # le début, piège d'implémentation identifié en revue).
            def total_similarity(key):
                return sum(similarity(key, other) for other in remaining if other != key)

            best_score = None
            seed_key = None
            # Tie-break déterministe : score desc, puis ancienneté desc,
            # puis key asc — reproductible d'un calcul à l'autre.
            for key in sorted(remaining, key=lambda k: (-remaining[k].waiting_hours, k)):
                score = total_similarity(key)
                if best_score is None or score > best_score:
                    best_score = score
                    seed_key = key

        seed = remaining.pop(seed_key)
        batch_keys = [seed_key]
        cumulative_products = Counter(seed.product_counts)
        cumulative_qty = seed.qty_total
        cumulative_lines = seed.line_count

        while True:
            if len(batch_keys) >= max_orders:
                break
            best_candidate = None
            best_candidate_score = None
            for key, order in remaining.items():
                new_qty = cumulative_qty + order.qty_total
                new_lines = cumulative_lines + order.line_count
                if new_qty > max_qty or new_lines > max_lines:
                    continue
                score = jaccard(cumulative_products, order.product_counts)
                if score < min_similarity:
                    continue
                # Tie-break : score desc, ancienneté desc, key asc.
                candidate_key_tuple = (-score, -order.waiting_hours, key)
                if best_candidate_score is None or candidate_key_tuple < best_candidate_score:
                    best_candidate_score = candidate_key_tuple
                    best_candidate = key

            if best_candidate is None:
                break

            chosen = remaining.pop(best_candidate)
            batch_keys.append(best_candidate)
            cumulative_products.update(chosen.product_counts)
            cumulative_qty += chosen.qty_total
            cumulative_lines += chosen.line_count

        batches.append(batch_keys)

    return batches
