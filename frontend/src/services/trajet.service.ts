// src/services/trajet.service.ts

import { api } from "./api";

// ─── Types ────────────────────────────────────────────────────────────────

export interface Vehicule {
  id: number;
  type_vehicule: string;
  marque: string;
  modele: string;
  couleur: string;
  plaque: string;
  places_max: number;
  est_actif: boolean;
}

export interface Trajet {
  id: number;
  conducteur: string;
  conducteur_nom: string;
  conducteur_note: number;
  vehicule: number | null;
  vehicule_info: Vehicule | null;
  type_vehicule: string | null;
  depart: string;
  depart_lat: number;
  depart_lng: number;
  destination: string;
  destination_lat: number;
  destination_lng: number;
  distance_km: number;
  cout_total: number;
  prix_par_place: number;
  date_heure_depart: string;
  places_disponibles: number;
  places_restantes: number;
  description: string;
  est_regulier: boolean;
  jours_semaine: string[] | null;
  statut: "ouvert" | "en_cours" | "termine" | "annule";
  polyline:            string;         // JSON string "[[lng,lat],...]" from OSRM
  polyline_stored:     boolean;
  tolerance_detour_km: number;
  created_at: string;
}

export interface TrajetCreatePayload {
  vehicule_id: number;
  depart: string;
  depart_lat: number;
  depart_lng: number;
  destination: string;
  destination_lat: number;
  destination_lng: number;
  distance_km: number;
  cout_total?: number;
  prix_par_place?: number;
  date_heure_depart: string;
  places_disponibles: number;
  description: string;
  est_regulier: boolean;
  jours_semaine: string[] | null;
  tolerance_km?: number;
}

export interface PrixBackendResult {
  distance_km:    number;
  tarif_km:       number;
  type_vehicule:  string;
  cout_carburant: number;
  commission:     number;
  cout_total:     number;
  capacite:       number;
  prix_par_place: number;
}

// ─── Tarifs selon type de véhicule ────────────────────────────────────────

const TARIF_PAR_TYPE: Record<string, number> = {
  moto: 30, // FCFA/km — 3L/100km × 700 FCFA/L ÷ 100
  voiture: 65, // FCFA/km — 8L/100km × 700 FCFA/L ÷ 100
  minibus: 120, // FCFA/km — 15L/100km × 700 FCFA/L ÷ 100
  camion: 200, // FCFA/km — 25L/100km × 700 FCFA/L ÷ 100
};

const COMMISSION = 0.1; // 10% KoVoit

// Places max par type (pour limiter le formulaire)
export const PLACES_MAX_PAR_TYPE: Record<string, number> = {
  moto: 1,
  voiture: 5,
  minibus: 15,
  camion: 3,
};

// ─── Calcul du prix ────────────────────────────────────────────────────────

// Calcule le coût total selon la distance ET le type de véhicule
export const calculerCoutTotal = (
  distance_km: number,
  type_vehicule: string,
): number => {
  const tarif = TARIF_PAR_TYPE[type_vehicule] ?? 65;
  const carburant = distance_km * tarif;
  const commission = carburant * COMMISSION;
  return Math.round(carburant + commission);
};

// Prix fixe par place — calculé une seule fois à la création
export const calculerPrixParPlace = (
  cout_total: number,
  places: number,
): number => {
  if (places <= 0) return 0;
  return Math.round(cout_total / places);
};

// Alias pour compatibilité
export const calculerPrixPrevu = calculerPrixParPlace;

// ─── API Tarification (backend) ───────────────────────────────────────────

export const calculerPrixBackend = (
  vehicule_id: number,
  distance_km: number,
): Promise<PrixBackendResult> =>
  api(`/trajets/calculer-prix/?vehicule_id=${vehicule_id}&distance_km=${distance_km}`, "GET");

// ─── API Trajets ───────────────────────────────────────────────────────────

export const creerTrajet = (data: TrajetCreatePayload) =>
  api("/trajets/", "POST", data);

export const mesTrajets = () => api("/trajets/mes_trajets/", "GET");

export const getTrajet = (id: number) => api(`/trajets/${id}/`, "GET");

export const modifierTrajet = (
  id: number,
  data: Partial<TrajetCreatePayload>,
) => api(`/trajets/${id}/`, "PUT", data);

export const commencerTrajet = (id: number) =>
  api(`/trajets/${id}/commencer/`, "POST");

export const terminerTrajet = (id: number) =>
  api(`/trajets/${id}/terminer/`, "POST");

export const annulerTrajet = (id: number) =>
  api(`/trajets/${id}/annuler/`, "POST");

export const rechercherTrajets = (
  params: {
    depart?: string;
    destination?: string;
    date?: string;
    places?: number;
    type_vehicule?: string;
  } = {},
) => {
  const query = new URLSearchParams();
  if (params.depart) query.append("depart", params.depart);
  if (params.destination) query.append("destination", params.destination);
  if (params.date) query.append("date", params.date);
  if (params.places) query.append("places", String(params.places));
  if (params.type_vehicule) query.append("type_vehicule", params.type_vehicule);
  const qs = query.toString();
  return api(`/trajets/rechercher/${qs ? "?" + qs : ""}`, "GET");
};

// ─── API Véhicules ─────────────────────────────────────────────────────────

export const mesVehicules = () => api("/utilisateurs/ko/vehicules/", "GET");

export const ajouterVehicule = (data: {
  type_vehicule: string;
  marque: string;
  modele: string;
  couleur: string;
  plaque: string;
  places_max: number;
}) => api("/utilisateurs/ko/vehicules/ajouter/", "POST", data);

export const desactiverVehicule = (id: number) =>
  api(`/utilisateurs/ko/vehicules/${id}/desactiver/`, "POST");

// ─── Backend-proxied : itinéraire, alertes, autocomplete ──────────────────

export interface RouteStep {
    instruction: string;
    distance_m:  number;
    duree_s:     number;
    nom_rue:     string;
}

export interface ItineraireRoute {
    distance_km: number;
    duree_min:   number;
    geometry:    { type: string; coordinates: number[][] };
    steps:       RouteStep[];
}

export interface ItineraireResult {
    trajet_id:   string;
    depart:      string;
    destination: string;
    routes:      ItineraireRoute[];
}

export const getItineraire = (trajetId: number | string, alternatives = false): Promise<ItineraireResult> =>
    api(`/trajets/${trajetId}/itineraire/?alternatives=${alternatives}`, "GET");

export const getAlertesRoutes = (type?: 'bloquee' | 'inondable' | 'impraticable'): Promise<unknown> => {
    const qs = type ? `?type=${type}` : '';
    return api(`/trajets/alertes-routes/${qs}`, "GET");
};

export const autocompleteVille = (q: string): Promise<{ nom: string; display: string; lat: number; lng: number }[]> => {
    if (q.length < 2) return Promise.resolve([]);
    return api(`/trajets/autocomplete/?q=${encodeURIComponent(q)}`, "GET");
};

// ─── Nominatim (OpenStreetMap) — Autocomplete lieux ───────────────────────

export interface NominatimResult {
  place_id: number;
  display_name: string;
  lat: string;
  lon: string;
  type: string;
  address: {
    suburb?: string;
    quarter?: string;
    neighbourhood?: string;
    city?: string;
    town?: string;
    village?: string;
    county?: string;
    country?: string;
  };
}

export const searchLieu = async (query: string): Promise<NominatimResult[]> => {
  if (query.length < 2) return [];
  const response = await fetch(
    `https://nominatim.openstreetmap.org/search?` +
    `q=${encodeURIComponent(query)}&` +
    `countrycodes=TG&` +
    `format=json&` +
    `addressdetails=1&` +
    `limit=6`,
    { headers: { "Accept-Language": "fr" } },
  );
  return response.json();
};

export const formatNominatimLabel = (result: NominatimResult): string => {
  const a = result.address;
  const quartier = a.suburb || a.quarter || a.neighbourhood || "";
  const ville = a.city || a.town || a.village || a.county || "";
  if (quartier && ville) return `${quartier}, ${ville}`;
  if (ville) return ville;
  return result.display_name.split(",").slice(0, 2).join(",").trim();
};

// ─── OSRM — Calcul distance routière ──────────────────────────────────────

export interface OSRMResult {
  distance_km: number;
  duration_min: number;
}

export const calculerDistance = async (
  depart: { lat: number; lng: number },
  destination: { lat: number; lng: number },
): Promise<OSRMResult> => {
  const coords = `${depart.lng},${depart.lat};${destination.lng},${destination.lat}`;
  const response = await fetch(
    `https://router.project-osrm.org/route/v1/driving/${coords}?overview=false`,
  );
  const data = await response.json();
  if (data.code !== "Ok" || !data.routes?.[0]) {
    throw new Error("Impossible de calculer la distance.");
  }
  return {
    distance_km: Math.round(data.routes[0].distance / 1000),
    duration_min: Math.round(data.routes[0].duration / 60),
  };
};

// ─── Recherche par itinéraire (OSRM matching) ─────────────────────────────

export interface MatchingInfo {
  score:                  number;
  distance_passager_km:   number;
  distance_pickup_km:     number | null;
  distance_dropoff_km:    number | null;
  detour_km:              number;
  direction_ok:           boolean;
  prix_passager:          number;
  raison:                 string;
}

export interface TrajetAvecMatching extends Trajet {
  matching?: MatchingInfo;
}

export const rechercherParItineraire = (params: {
  pickup_lat: number;
  pickup_lng: number;
  dropoff_lat: number;
  dropoff_lng: number;
  date?: string;
  places?: number;
  score_minimum?: number;
  tolerance_km?: number;   // 0.5 | 1 | 2 | 3 | 5
}): Promise<{ count: number; tolerance_km: number; algorithm: string; resultats: TrajetAvecMatching[] }> =>
  api("/trajets/rechercher-itineraire/", "POST", params);

// ─── Escales (TripStop) ────────────────────────────────────────────────────

export interface Escale {
  id?: number;
  nom: string;
  lat: number;
  lng: number;
  ordre: number;
  heure_prevue?: string;
  heure_reelle?: string;
  statut?: string;
}

export const getEscales = (trajetId: number): Promise<Escale[]> =>
  api(`/trajets/${trajetId}/escales/`, "GET");

export const ajouterEscale = (trajetId: number, escale: Omit<Escale, "id">): Promise<Escale> =>
  api(`/trajets/${trajetId}/escales/`, "POST", escale);

export const supprimerEscale = (trajetId: number, escaleId: number): Promise<void> =>
  api(`/trajets/${trajetId}/escales/${escaleId}/`, "DELETE");

export const mettreAJourEscale = (trajetId: number, escaleId: number, data: Partial<Escale>): Promise<Escale> =>
  api(`/trajets/${trajetId}/escales/${escaleId}/`, "PATCH", data);

// ─── Code d'embarquement (passager) ──────────────────────────────────────

export const getCodeEmbarquement = (reservationId: string): Promise<{
  code_embarquement: string;
  trajet: string;
  date_depart: string;
  statut_embarquement: string;
  prix_passager: number | null;
}> => api(`/reservations/${reservationId}/code-embarquement/`, "GET");

export const embarquerPassager = (code: string): Promise<{
  message: string;
  passager: string;
  heure_embarquement: string;
}> => api("/reservations/embarquer/", "POST", { code_embarquement: code });

export const debarquerPassager = (reservationId: string): Promise<{
  message: string;
  passager: string;
  heure_depose: string;
}> => api(`/reservations/${reservationId}/debarquer/`, "POST");

// ─── Parse stored OSRM polyline ──────────────────────────────────────────────

export const parsePolyline = (polylineJson: string): [number, number][] | null => {
  if (!polylineJson) return null;
  try {
    const coords = JSON.parse(polylineJson);
    if (Array.isArray(coords) && coords.length >= 2) {
      return coords as [number, number][];
    }
  } catch {}
  return null;
};
