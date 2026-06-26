"""
Service de tarification KoVoit — calcul 100% côté serveur.

Formule BlaBlaCar :
  cout_carburant = distance_km × tarif_km
  commission     = cout_carburant × 10%
  cout_total     = cout_carburant + commission
  prix_par_place = cout_total ÷ capacite_reelle_vehicule   (places_max, PAS places_disponibles)
"""

TARIF_PAR_KM: dict = {
    'moto':    30.0,
    'voiture': 65.0,
    'minibus': 120.0,
    'camion':  200.0,
}
TARIF_DEFAUT    = 65.0
TAUX_COMMISSION = 0.10

# Capacité réelle par défaut selon le type (utilisée si vehicule.places_max absent)
CAPACITE_PAR_TYPE: dict = {
    'moto':    1,
    'voiture': 4,
    'minibus': 12,
    'camion':  2,
}
CAPACITE_DEFAUT = 4


def capacite_vehicule(vehicule_obj) -> int:
    """Retourne la capacité réelle du véhicule (places_max) ou le défaut par type."""
    if vehicule_obj is None:
        return CAPACITE_DEFAUT
    places_max = getattr(vehicule_obj, 'places_max', None)
    if places_max:
        return max(1, int(places_max))
    type_v = str(getattr(vehicule_obj, 'type_vehicule', '') or '').lower().strip()
    return CAPACITE_PAR_TYPE.get(type_v, CAPACITE_DEFAUT)


def type_vehicule_str(vehicule_obj) -> str:
    if vehicule_obj is None:
        return 'voiture'
    return str(getattr(vehicule_obj, 'type_vehicule', '') or 'voiture').lower().strip()


def calculer_prix(distance_km: float, type_veh: str, cap: int) -> dict:
    """
    Calcule le prix complet. Retourne un dict avec tous les détails.
    cap = capacité RÉELLE du véhicule (places_max), PAS places_disponibles.
    """
    type_v = str(type_veh).lower().strip()
    tarif  = TARIF_PAR_KM.get(type_v, TARIF_DEFAUT)
    cap    = max(1, int(cap))

    cout_carburant = round(float(distance_km) * tarif, 2)
    commission     = round(cout_carburant * TAUX_COMMISSION, 2)
    cout_total     = round(cout_carburant + commission, 2)
    prix_par_place = max(1, round(cout_total / cap))

    return {
        'distance_km':    round(float(distance_km), 3),
        'tarif_km':       tarif,
        'type_vehicule':  type_v,
        'cout_carburant': cout_carburant,
        'commission':     commission,
        'cout_total':     cout_total,
        'capacite':       cap,
        'prix_par_place': int(prix_par_place),
    }


def calculer_prix_trajet(trajet) -> dict:
    """Prix complet d'un trajet depuis l'objet Trajet Django."""
    veh  = getattr(trajet, 'vehicule', None)
    dist = float(trajet.distance_km or 0)
    return calculer_prix(dist, type_vehicule_str(veh), capacite_vehicule(veh))


def calculer_prix_segment(distance_passager_km: float, trajet) -> dict:
    """Prix pour un passager qui ne parcourt qu'une partie du trajet."""
    veh = getattr(trajet, 'vehicule', None)
    return calculer_prix(
        float(distance_passager_km),
        type_vehicule_str(veh),
        capacite_vehicule(veh),
    )
