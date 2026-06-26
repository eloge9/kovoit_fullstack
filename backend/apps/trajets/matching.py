"""
Moteur de matching géographique conducteur ↔ passager — v2.

Principe v2 (polyline stockée) :
  1. Lit la polyline OSRM stockée en base (format JSON [[lng, lat], ...]).
  2. Calcule la distance perpendiculaire minimale pickup→route et dropoff→route.
  3. Vérifie le sens : pickup doit précéder dropoff sur l'itinéraire.
  4. Calcule la distance passager en suivant les segments de la polyline.
  5. Retourne un score 0-100 et le prix proportionnel.

Fallback haversine si la polyline n'est pas encore stockée.
Utilise Shapely si disponible (pip install shapely).
"""
import json
import math
import logging
import requests

logger = logging.getLogger(__name__)

OSRM_BASE       = "https://router.project-osrm.org"
EARTH_RADIUS_KM = 6371.0
DEGREES_TO_KM   = 111.0   # 1 degré ≈ 111 km

# ── Détection Shapely ──────────────────────────────────────────────────────────
try:
    from shapely.geometry import LineString, Point as ShapelyPoint
    SHAPELY_AVAILABLE = True
except ImportError:
    SHAPELY_AVAILABLE = False
    logger.info("Shapely non disponible — distance perpendiculaire approximative (degrés×111 km)")


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
    """Distance (degrés) entre un point P et le segment AB."""
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def _min_distance_to_polyline(lat: float, lng: float, coords: list) -> float:
    """Distance minimale en km entre un point et une polyline [[lng, lat], ...]."""
    if not coords or len(coords) < 2:
        return float("inf")
    min_dist = float("inf")
    for i in range(len(coords) - 1):
        a_lng, a_lat = coords[i]
        b_lng, b_lat = coords[i + 1]
        deg_dist = _point_to_segment_distance(lng, lat, a_lng, a_lat, b_lng, b_lat)
        km_dist  = deg_dist * DEGREES_TO_KM
        if km_dist < min_dist:
            min_dist = km_dist
    return min_dist


def _distance_to_polyline(lat: float, lng: float, coords: list) -> float:
    """
    Distance perpendiculaire en km — utilise Shapely si disponible,
    sinon repli sur _min_distance_to_polyline.
    """
    if not SHAPELY_AVAILABLE:
        return _min_distance_to_polyline(lat, lng, coords)

    # Projection conforme approximative : corriger la déformation en longitude
    lat_scale = math.cos(math.radians(lat))
    scaled    = [(c[0] * lat_scale, c[1]) for c in coords]
    line      = LineString(scaled)
    pt        = ShapelyPoint(lng * lat_scale, lat)
    return line.distance(pt) * DEGREES_TO_KM


def _find_projection_index(point_lng: float, point_lat: float, coords: list) -> int:
    """
    Retourne l'indice du segment où le point se projette le plus près.
    Utilisé pour la vérification de sens : idx_pickup < idx_dropoff.
    """
    min_dist = float("inf")
    best_idx = 0
    for i in range(len(coords) - 1):
        a_lng, a_lat = coords[i]
        b_lng, b_lat = coords[i + 1]
        d = _point_to_segment_distance(point_lng, point_lat, a_lng, a_lat, b_lng, b_lat)
        if d < min_dist:
            min_dist = d
            best_idx = i
    return best_idx


def _passenger_segment_distance(
    pickup_idx: int,
    dropoff_idx: int,
    coords: list,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
) -> float:
    """
    Distance routière du segment passager calculée en suivant
    les segments de la polyline entre la projection du pickup et celle du dropoff.
    Évite un appel OSRM supplémentaire.
    """
    if pickup_idx >= dropoff_idx:
        return _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)

    total = 0.0

    # Du point pickup jusqu'à la fin de son segment
    next_lng, next_lat = coords[pickup_idx + 1]
    total += _haversine(pickup_lat, pickup_lng, next_lat, next_lng)

    # Segments intermédiaires complets
    for i in range(pickup_idx + 1, dropoff_idx):
        a_lng, a_lat = coords[i]
        b_lng, b_lat = coords[i + 1]
        total += _haversine(a_lat, a_lng, b_lat, b_lng)

    # Du début du segment dropoff jusqu'au point dropoff
    start_lng, start_lat = coords[dropoff_idx]
    total += _haversine(start_lat, start_lng, dropoff_lat, dropoff_lng)

    # Ne jamais retourner moins que la distance à vol d'oiseau
    return max(total, _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng))


# ── OSRM ──────────────────────────────────────────────────────────────────────

def _get_osrm_route(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
) -> dict | None:
    """Récupère la route OSRM. Retourne None si indisponible."""
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
                "coords": route["geometry"]["coordinates"],   # [[lng, lat], ...]
            }
    except Exception as e:
        logger.warning("OSRM route error: %s", e)
    return None


def _get_osrm_distance(
    from_lat: float, from_lng: float,
    to_lat: float, to_lng: float,
) -> float | None:
    route = _get_osrm_route(from_lat, from_lng, to_lat, to_lng)
    return route["distance_km"] if route else None


# ── Stockage polyline ─────────────────────────────────────────────────────────

def fetch_and_store_polyline(trajet) -> bool:
    """
    Récupère la route OSRM pour un trajet et stocke la polyline en base.
    Non-bloquant : retourne False en cas d'échec (le trajet reste valide).

    Format stocké : JSON string de [[lng, lat], [lng, lat], ...]
    (format natif OSRM GeoJSON coordinates).
    """
    if not (trajet.depart_lat and trajet.depart_lng and
            trajet.destination_lat and trajet.destination_lng):
        return False

    route = _get_osrm_route(
        trajet.depart_lat, trajet.depart_lng,
        trajet.destination_lat, trajet.destination_lng,
    )
    if not route:
        return False

    coords = route["coords"]
    polyline_json = json.dumps(coords)

    # Utiliser queryset.update() pour éviter de déclencher full_clean()
    from apps.modeles.models import Trajet as TrajetModel
    TrajetModel.objects.filter(pk=trajet.pk).update(
        polyline=polyline_json,
        polyline_stored=True,
        distance_km=round(route["distance_km"], 2),
    )
    # Mettre à jour l'instance en mémoire aussi
    trajet.polyline        = polyline_json
    trajet.polyline_stored = True
    trajet.distance_km     = round(route["distance_km"], 2)
    return True


def _decode_stored_polyline(trajet) -> list | None:
    """Décode la polyline JSON stockée. Retourne None si absente ou invalide."""
    if not getattr(trajet, 'polyline_stored', False) or not trajet.polyline:
        return None
    try:
        coords = json.loads(trajet.polyline)
        if isinstance(coords, list) and len(coords) >= 2:
            return coords
    except (json.JSONDecodeError, TypeError, ValueError):
        pass
    return None


# ── Score de compatibilité v2 (polyline stockée) ─────────────────────────────

def calculer_score_matching_v2(
    trajet,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
    tolerance_km: float = 2.0,
) -> dict:
    """
    Algorithme v2 — utilise la polyline stockée pour :
      1. Distance perpendiculaire pickup→route
      2. Distance perpendiculaire dropoff→route
      3. Vérification du sens (pickup avant dropoff sur l'itinéraire)
      4. Distance passager le long de la route (sans appel OSRM)
      5. Score 0-100

    Repli automatique sur haversine si polyline non stockée.
    """
    coords = _decode_stored_polyline(trajet)

    if coords is None:
        # Repli haversine
        return _score_haversine_fallback(
            trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, tolerance_km
        )

    # 1. Distances perpendiculaires
    dist_pickup  = _distance_to_polyline(pickup_lat,  pickup_lng,  coords)
    dist_dropoff = _distance_to_polyline(dropoff_lat, dropoff_lng, coords)

    # 2. Vérification pickup trop loin
    if dist_pickup > tolerance_km:
        return {
            "score": 0, "compatible": False,
            "distance_pickup_to_route_km":  round(dist_pickup, 2),
            "distance_dropoff_to_route_km": round(dist_dropoff, 2),
            "distance_passager_km": 0.0,
            "detour_estime_km": round(dist_pickup, 2),
            "direction_ok": False,
            "raison": (
                f"Prise en charge trop éloignée ({dist_pickup:.1f} km > "
                f"tolérance {tolerance_km} km)"
            ),
        }

    # 3. Vérification dropoff trop loin
    if dist_dropoff > tolerance_km:
        return {
            "score": 0, "compatible": False,
            "distance_pickup_to_route_km":  round(dist_pickup, 2),
            "distance_dropoff_to_route_km": round(dist_dropoff, 2),
            "distance_passager_km": 0.0,
            "detour_estime_km": round(dist_dropoff, 2),
            "direction_ok": False,
            "raison": (
                f"Point de dépose trop éloigné ({dist_dropoff:.1f} km > "
                f"tolérance {tolerance_km} km)"
            ),
        }

    # 4. Vérification du sens
    pickup_idx  = _find_projection_index(pickup_lng,  pickup_lat,  coords)
    dropoff_idx = _find_projection_index(dropoff_lng, dropoff_lat, coords)

    if pickup_idx >= dropoff_idx:
        return {
            "score": 5, "compatible": False,
            "distance_pickup_to_route_km":  round(dist_pickup, 2),
            "distance_dropoff_to_route_km": round(dist_dropoff, 2),
            "distance_passager_km": 0.0,
            "detour_estime_km": 0.0,
            "direction_ok": False,
            "raison": "La dépose précède la prise en charge (sens inverse)",
        }

    # 5. Distance passager le long de la route
    distance_passager_km = _passenger_segment_distance(
        pickup_idx, dropoff_idx, coords,
        pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    )

    # 6. Score composite
    # Composante proximité pickup (0-50 pts)
    prox_pickup = max(0.0, 50.0 * (1.0 - dist_pickup / tolerance_km))
    # Composante proximité dropoff (0-30 pts)
    prox_dropoff = max(0.0, 30.0 * (1.0 - dist_dropoff / tolerance_km))
    # Bonus sens correct (20 pts fixes)
    direction_bonus = 20.0
    score = round(prox_pickup + prox_dropoff + direction_bonus)

    return {
        "score": min(100, max(0, score)),
        "compatible": True,
        "distance_pickup_to_route_km":  round(dist_pickup, 2),
        "distance_dropoff_to_route_km": round(dist_dropoff, 2),
        "distance_passager_km": round(distance_passager_km, 2),
        "detour_estime_km": round(dist_pickup + dist_dropoff, 2),
        "direction_ok": True,
        "raison": "Trajet compatible",
    }


def _score_haversine_fallback(
    trajet,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
    tolerance_km: float,
) -> dict:
    """Fallback sans polyline stockée : distance haversine du départ du trajet."""
    dist = _haversine(
        pickup_lat, pickup_lng,
        trajet.depart_lat or 0, trajet.depart_lng or 0,
    )
    distance_passager = _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    compatible        = dist <= tolerance_km * 2
    score             = max(0, 60 - int((dist / max(tolerance_km, 0.01)) * 30)) if compatible else 0
    return {
        "score": score,
        "compatible": compatible,
        "distance_pickup_to_route_km":  round(dist, 2),
        "distance_dropoff_to_route_km": None,
        "distance_passager_km": round(distance_passager, 2),
        "detour_estime_km": round(dist, 2),
        "direction_ok": compatible,
        "raison": "Calcul approximatif (itinéraire non encore stocké)",
    }


# ── Score v1 (legacy — garde pour /matching-score endpoint) ──────────────────

def calculer_score_matching(
    trajet,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
    tolerance_km: float | None = None,
) -> dict:
    """Version 1 — préservée pour rétrocompatibilité (endpoint matching-score)."""
    if tolerance_km is None:
        tolerance_km = getattr(trajet, "tolerance_detour_km", 2.0)

    route = _get_osrm_route(
        trajet.depart_lat, trajet.depart_lng,
        trajet.destination_lat, trajet.destination_lng,
    )
    if not route:
        return _score_haversine_fallback(
            trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, tolerance_km
        )

    coords           = route["coords"]
    distance_totale  = route["distance_km"]
    dist_pickup      = _min_distance_to_polyline(pickup_lat,  pickup_lng,  coords)
    dist_dropoff     = _min_distance_to_polyline(dropoff_lat, dropoff_lng, coords)
    segment          = _get_osrm_distance(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    distance_passager = segment if segment else _haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    detour_km        = dist_pickup

    if dist_pickup > tolerance_km:
        return {
            "score": 0, "compatible": False,
            "distance_pickup_to_route_km":  round(dist_pickup, 2),
            "distance_passager_km": round(distance_passager, 2),
            "detour_estime_km": round(detour_km, 2),
            "raison": f"Point de prise en charge trop éloigné ({dist_pickup:.1f} km)",
        }
    if dist_dropoff > tolerance_km:
        return {
            "score": 0, "compatible": False,
            "distance_pickup_to_route_km":  round(dist_pickup, 2),
            "distance_passager_km": round(distance_passager, 2),
            "detour_estime_km": round(detour_km, 2),
            "raison": f"Point de dépose trop éloigné ({dist_dropoff:.1f} km)",
        }

    proximity_score  = max(0, 100 - (dist_pickup / tolerance_km) * 60)
    direction_score  = 50 if distance_passager > distance_totale * 1.1 else 100
    score            = round(proximity_score * 0.7 + direction_score * 0.3)

    return {
        "score": min(100, max(0, score)),
        "compatible": True,
        "distance_pickup_to_route_km": round(dist_pickup, 2),
        "distance_passager_km": round(distance_passager, 2),
        "detour_estime_km": round(detour_km, 2),
        "raison": "Trajet compatible",
    }


# ── Tarification au km par type de véhicule ──────────────────────────────────

TARIF_PAR_VEHICULE: dict[str, int] = {
    'moto':    30,
    'voiture': 65,
    'minibus': 120,
    'camion':  200,
}

# Taux par défaut si le type de véhicule est inconnu
_TARIF_DEFAUT = 65


def calculer_prix_par_km(
    distance_km: float,
    type_vehicule: str,
    places: int = 1,
) -> int:
    """
    Prix passager = (distance × tarif_km × (1 + commission)) ÷ places_disponibles.
    Arrondi à l'entier le plus proche, minimum 25 FCFA.

    Exemples (120 km, Lomé → Kpalimé) :
        moto    1pl  → 120×30×1.10/1  = 3 960 FCFA
        voiture 4pl  → 120×65×1.10/4  = 2 145 FCFA
        minibus 12pl → 120×120×1.10/12 = 1 320 FCFA
        camion  2pl  → 120×200×1.10/2 = 13 200 FCFA
    """
    tarif           = TARIF_PAR_VEHICULE.get(str(type_vehicule).lower().strip(), _TARIF_DEFAUT)
    cout_carburant  = distance_km * tarif
    avec_commission = cout_carburant * (1 + COMMISSION_KOVOIT)
    places          = max(1, int(places))
    # round(..., 4) élimine les artefacts flottants avant l'arrondi final
    prix_unitaire   = round(avec_commission / places, 4)
    return max(25, round(prix_unitaire))


# ── Tarification proportionnelle (legacy — garde pour rétrocompatibilité) ─────

COMMISSION_KOVOIT = 0.10


def calculer_prix_passager(
    distance_passager_km: float,
    distance_totale_km: float,
    prix_total: float,
    commission: float = COMMISSION_KOVOIT,
) -> int:
    """Legacy — utilise calculer_prix_par_km() de préférence."""
    if distance_totale_km <= 0:
        return int(prix_total)
    ratio      = min(1.0, distance_passager_km / distance_totale_km)
    base       = prix_total * ratio
    avec_comm  = base * (1 + commission)
    return int(math.ceil(avec_comm / 25) * 25)


# ── Recherche v2 — utilise les polylines stockées ────────────────────────────

VALID_TOLERANCES = [0.5, 1.0, 2.0, 3.0, 5.0]


def rechercher_trajets_compatibles_v2(
    trajets_queryset,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
    tolerance_km: float = 2.0,
    score_minimum: int = 50,
) -> list[dict]:
    """
    V2 : utilise les polylines stockées en base.
    Aucun appel OSRM pendant la recherche.

    Tri : score DESC → détour ASC → prix ASC → note conducteur DESC
    """
    # Clamper la tolérance aux valeurs valides
    tolerance_km = min(VALID_TOLERANCES, key=lambda t: abs(t - tolerance_km))

    results = []
    for trajet in trajets_queryset:
        if not all([trajet.depart_lat, trajet.depart_lng,
                    trajet.destination_lat, trajet.destination_lng]):
            continue

        match = calculer_score_matching_v2(
            trajet,
            pickup_lat, pickup_lng,
            dropoff_lat, dropoff_lng,
            tolerance_km=tolerance_km,
        )

        if not match["compatible"] or match["score"] < score_minimum:
            continue

        from .tarification import calculer_prix_segment
        tarif_seg = calculer_prix_segment(match["distance_passager_km"], trajet)
        prix = tarif_seg['prix_par_place']
        note = getattr(getattr(trajet, 'conducteur', None), 'note', 0) or 0

        results.append({
            "trajet":               trajet,
            "score":                match["score"],
            "distance_passager_km": match["distance_passager_km"],
            "detour_km":            match["detour_estime_km"],
            "prix_passager":        prix,
            "direction_ok":         match["direction_ok"],
            "distance_pickup_km":   match["distance_pickup_to_route_km"],
            "distance_dropoff_km":  match.get("distance_dropoff_to_route_km"),
            "raison":               match["raison"],
            "_note":                note,
        })

    results.sort(key=lambda x: (
        -x["score"],
        x["detour_km"],
        x["prix_passager"],
        -x["_note"],
    ))
    return results


# ── Recherche v1 (legacy — garde pour rétrocompatibilité) ────────────────────

def rechercher_trajets_compatibles(
    trajets_queryset,
    pickup_lat: float, pickup_lng: float,
    dropoff_lat: float, dropoff_lng: float,
    score_minimum: int = 50,
) -> list[dict]:
    """V1 — préservée pour rétrocompatibilité."""
    results = []
    for trajet in trajets_queryset:
        if not all([trajet.depart_lat, trajet.depart_lng,
                    trajet.destination_lat, trajet.destination_lng]):
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
                "trajet":               trajet,
                "score":                match["score"],
                "distance_passager_km": match["distance_passager_km"],
                "detour_km":            match["detour_estime_km"],
                "prix_passager":        prix,
                "raison":               match["raison"],
            })
    results.sort(key=lambda x: x["score"], reverse=True)
    return results
