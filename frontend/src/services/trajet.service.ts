// src/services/trajet.service.ts

import { api } from "./api";

export interface Escale {
  nom: string;
  lat: number;
  lng: number;
}

export interface TrajetCreatePayload {
  depart: string;
  depart_lat: number;
  depart_lng: number;
  destination: string;
  destination_lat: number;
  destination_lng: number;
  escales: Escale[];
  distance_km: number;
  prix_par_place: number;
  date_heure_depart: string; // ISO string
  places_disponibles: number;
  description: string;
  est_regulier: boolean;
  jours_semaine: string[] | null;
}

export interface Trajet {
  id: number;
  conducteur: string;
  conducteur_nom: string;
  conducteur_note: number;
  depart: string;
  depart_lat: number;
  depart_lng: number;
  destination: string;
  destination_lat: number;
  destination_lng: number;
  escales: Escale[];
  distance_km: number;
  prix_par_place: number;
  date_heure_depart: string;
  places_disponibles: number;
  places_restantes: number;
  description: string;
  est_regulier: boolean;
  jours_semaine: string[] | null;
  statut: "ouvert" | "termine" | "annule";
  created_at: string;
}

// Créer un trajet
export const creerTrajet = (data: TrajetCreatePayload) =>
  api("/trajets/", "POST", data);

// Mes trajets (conducteur)
export const mesTrajets = () => api("/trajets/mes_trajets/", "GET");

// Détail d'un trajet
export const getTrajet = (id: number) => api(`/trajets/${id}/`, "GET");

// Modifier un trajet
export const modifierTrajet = (
  id: number,
  data: Partial<TrajetCreatePayload>,
) => api(`/trajets/${id}/`, "PUT", data);

// Annuler un trajet
export const annulerTrajet = (id: number) =>
  api(`/trajets/${id}/annuler/`, "POST");

// Rechercher des trajets
export const rechercherTrajets = (params: {
  depart?:        string;
  destination?:   string;
  date?:          string;
  places?:        number;
  type_vehicule?: string;
} = {}) => {
  const query = new URLSearchParams();
  if (params.depart)        query.append("depart",        params.depart);
  if (params.destination)   query.append("destination",   params.destination);
  if (params.date)          query.append("date",          params.date);
  if (params.places)        query.append("places",        String(params.places));
  if (params.type_vehicule) query.append("type_vehicule", params.type_vehicule);
  const qs = query.toString();
  return api(`/trajets/rechercher/${qs ? "?" + qs : ""}`, "GET");
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
      `countrycodes=TG&` + // limiter au Togo
      `format=json&` +
      `addressdetails=1&` +
      `limit=6`,
    { headers: { "Accept-Language": "fr" } },
  );
  return response.json();
};

// Formatage du nom affiché
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
  escales: { lat: number; lng: number }[] = [],
): Promise<OSRMResult> => {
  // Construire les waypoints : départ + escales + destination
  const points = [depart, ...escales, destination];
  const coords = points.map((p) => `${p.lng},${p.lat}`).join(";");

  const response = await fetch(
    `https://router.project-osrm.org/route/v1/driving/${coords}` +
      `?overview=false`,
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

// ─── Calcul du prix ────────────────────────────────────────────────────────

const TARIF_KM = 65;
const COMMISSION = 0.1; // 10% KoVoit

export const calculerCoutTotal = (distance_km: number): number => {
  const carburant = distance_km * TARIF_KM;
  const commission = carburant * COMMISSION;
  return Math.round(carburant + commission);
};

export const calculerPrixPrevu = (
  cout_total: number,
  places: number,
): number => {
  return Math.round(cout_total / places);
};

export const calculerPrixReel = (
  cout_total: number,
  nb_passagers: number,
): number => {
  if (nb_passagers === 0) return 0;
  return Math.round(cout_total / nb_passagers);
};
