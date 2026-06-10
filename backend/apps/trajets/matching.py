"""
Moteur de matching géographique conducteur ↔ passager.

Principe :
  1. Récupère la route OSRM du conducteur (liste de coordonnées).
  2. Pour un point de prise en charge passager, calcule la distance perpendiculaire
     minimale entre ce point et le tracé de la route.
  3. Calcule la distance réelle du segment passager (pickup → dropoff) sur la route.
  4. Retourne un score de compatibilité 0-100.

Utilise l'API OSRM publique (project-osrm.org) — aucune clé requise.
"""
import math
import logging
import requests

logger = logging.getLogger(__name__)

OSRM_BASE = "https://router.project-osrm.org"
EARTH_RADIUS_KM = 6371.0


# ── Géométrie de base ─────────────────────────────────────────────────────────

def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance en km entre deux coordonnées GPS."""
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def _point_to_segment_distance(
    px: float, py: float,
    ax: float, ay: float,
    bx: float, by: float,
) -> float:
    """Distance (en degrés, approximative) entre un point P et le segment AB."""
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    nearest_x = ax + t * dx
    nearest_y = ay + t * dy
    return math.hypot(px - nearest_x, py - nearest_y)


def _min_distance_to_polyline(lat: float, lng: float, coords: list[list[float]]) -> float:
    """Distance minimale en km entre un point et une polyline (liste de [lng, lat])."""
    if not coords or len(coords) < 2:
        return float("inf")
    min_dist = float("inf")
    for i in range(len(coords) - 1):
        a_lng, a_lat = coords[i]
        b_lng, b_lat = coords[i + 1]
        # Distance approximative en degrés → convertir en km
        deg_dist = _point_to_segment_distance(lng, lat, a_lng, a_lat, b_lng, b_lat)
        km_dist = deg_dist * 111.0  # 1 degré ≈ 111 km
        if km_dist < min_dist:
            min_dist = km_dist
    return min_dist


# ── Appels OSRM ───────────────────────────────────────────────────────────────

def _get_osrm_route(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
) -> dict | None:
    """Récupère la route OSRM entre deux points. Retourne None si erreur."""
    url = (
        f"{OSRM_BASE}/route/v1/driving/"
        f"{from_lng},{from_lat};{to_lng},{to_lat}"
        f"?overview=full&geometries=geojson"
    )
    try:
        resp = requests.get(url, timeout=5)
        data = resp.json()
        if data.get("code") == "Ok" and data.get("routes"):
            route = data["routes"][0]
            return {
                "distance_km": route["distance"] / 1000,
                "duration_min": route["duration"] / 60,
                "coords": route["geometry"]["coordinates"],  # [[lng, lat], ...]
            }
    except Exception as e:
        logger.warning("OSRM route error: %s", e)
    return None


def _get_osrm_distance(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
) -> float | None:
    """Retourne la distance routière en km entre deux points."""
    route = _get_osrm_route(from_lat, from_lng, to_lat, to_lng)
    return route["distance_km"] if route else None


# ── Score de compatibilité ────────────────────────────────────────────────────

def calculer_score_matching(
    trajet,
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
    tolerance_km: float | None = None,
) -> dict:
    """
    Calcule le score de compatibilité entre un trajet conducteur et une demande passager.

    Paramètres :
        trajet       : instance Trajet
        pickup_lat/lng  : coordonnées de prise en charge du passager
        dropoff_lat/lng : coordonnées de dépose du passager
        tolerance_km : détour max accepté (défaut : trajet.tolerance_detour_km)

    Retourne :
        {
            "score": 0-100,
            "compatible": bool,
            "distance_pickup_to_route_km": float,
            "distance_passager_km": float,
            "detour_estime_km": float,
            "raison": str,
        }
    """
    if tolerance_km is None:
        tolerance_km = getattr(trajet, "tolerance_detour_km", 2.0)

    # 1. Route du conducteur
    route = _get_osrm_route(
        trajet.depart_lat, trajet.depart_lng,
        trajet.destination_lat, trajet.destination_lng,
    )
    if not route:
        # Fallback haversine si OSRM indisponible
        return _score_haversine_fallback(trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, tolerance_km)

    coords = route["coords"]
    distance_totale_km = route["distance_km"]

    # 2. Distance du pickup passager par rapport à la route
    dist_pickup = _min_distance_to_polyline(pickup_lat, pickup_lng, coords)
    dist_dropoff = _min_distance_to_polyline(dropoff_lat, dropoff_lng, coords)

    # 3. Distance réelle du segment passager
    segment = _get_osrm_distance(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    distance_passager_km = segment if segment else _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)

    # 4. Détour estimé (pickup hors route)
    detour_km = max(dist_pickup, 0.0)

    # 5. Vérifications de base
    if dist_pickup > tolerance_km:
        return {
            "score": 0,
            "compatible": False,
            "distance_pickup_to_route_km": round(dist_pickup, 2),
            "distance_passager_km": round(distance_passager_km, 2),
            "detour_estime_km": round(detour_km, 2),
            "raison": f"Point de prise en charge trop éloigné de la route ({dist_pickup:.1f} km > {tolerance_km} km)",
        }

    if dist_dropoff > tolerance_km:
        return {
            "score": 0,
            "compatible": False,
            "distance_pickup_to_route_km": round(dist_pickup, 2),
            "distance_passager_km": round(distance_passager_km, 2),
            "detour_estime_km": round(detour_km, 2),
            "raison": f"Point de dépose trop éloigné de la route ({dist_dropoff:.1f} km > {tolerance_km} km)",
        }

    # 6. Score : 100 si exactement sur la route, décroissant selon l'éloignement
    proximity_score = max(0, 100 - (dist_pickup / tolerance_km) * 60)

    # Bonus si pickup/dropoff sont dans le sens du trajet (pas de demi-tour)
    direction_score = 100
    if distance_passager_km > distance_totale_km * 1.1:
        direction_score = 50  # Le segment passager dépasse le trajet

    score = round((proximity_score * 0.7 + direction_score * 0.3))

    return {
        "score": min(100, max(0, score)),
        "compatible": True,
        "distance_pickup_to_route_km": round(dist_pickup, 2),
        "distance_passager_km": round(distance_passager_km, 2),
        "detour_estime_km": round(detour_km, 2),
        "raison": "Trajet compatible",
    }


def _score_haversine_fallback(trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, tolerance_km):
    """Fallback sans OSRM : distance vol d'oiseau depuis le trajet."""
    dist = _haversine(pickup_lat, pickup_lng, trajet.depart_lat or 0, trajet.depart_lng or 0)
    distance_passager = _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    compatible = dist <= tolerance_km * 2
    score = max(0, 80 - int((dist / tolerance_km) * 40)) if compatible else 0
    return {
        "score": score,
        "compatible": compatible,
        "distance_pickup_to_route_km": round(dist, 2),
        "distance_passager_km": round(distance_passager, 2),
        "detour_estime_km": round(dist, 2),
        "raison": "Calcul approximatif (OSRM indisponible)",
    }


# ── Tarification proportionnelle ──────────────────────────────────────────────

COMMISSION_KOVOIT = 0.10  # 10%


def calculer_prix_passager(
    distance_passager_km: float,
    distance_totale_km: float,
    prix_total: float,
    commission: float = COMMISSION_KOVOIT,
) -> int:
    """
    Prix passager = (distance_passager / distance_totale) × prix_total + commission.
    Arrondi au multiple de 25 FCFA supérieur.
    """
    if distance_totale_km <= 0:
        return int(prix_total)
    ratio = min(1.0, distance_passager_km / distance_totale_km)
    base = prix_total * ratio
    avec_commission = base * (1 + commission)
    # Arrondi au multiple de 25 supérieur
    return int(math.ceil(avec_commission / 25) * 25)


# ── Recherche de trajets compatibles ─────────────────────────────────────────

def rechercher_trajets_compatibles(
    trajets_queryset,
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
    score_minimum: int = 50,
) -> list[dict]:
    """
    Filtre et classe les trajets par score de compatibilité.
    Retourne une liste de dicts {trajet, score, distance_passager_km, prix_passager}.
    """
    results = []
    for trajet in trajets_queryset:
        if not all([trajet.depart_lat, trajet.depart_lng, trajet.destination_lat, trajet.destination_lng]):
            continue
        match = calculer_score_matching(trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        if match["score"] >= score_minimum:
            prix = calculer_prix_passager(
                match["distance_passager_km"],
                trajet.distance_km or _haversine(
                    trajet.depart_lat, trajet.depart_lng,
                    trajet.destination_lat, trajet.destination_lng,
                ),
                float(trajet.cout_total or trajet.prix_par_place),
            )
            results.append({
                "trajet": trajet,
                "score": match["score"],
                "distance_passager_km": match["distance_passager_km"],
                "detour_km": match["detour_estime_km"],
                "prix_passager": prix,
                "raison": match["raison"],
            })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results
