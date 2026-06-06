// Types pour le suivi GPS en temps réel

export interface PositionGPS {
  latitude: number;
  longitude: number;
  precision?: number;
  vitesse_kmh?: number;
  direction?: number;
  timestamp?: string;
}

export interface SuiviInfo {
  distance_restante_km?: number;
  temps_restant_minutes?: number;
  distance_parcourue_km?: number;
  heure_arrivee_estimee?: string;
  statut?: string;
}

export interface Trajet {
  id: number;
  conducteur: string;
  conducteur_nom?: string;
  conducteur_note?: number;
  vehicule?: number | null;
  vehicule_info?: any;
  type_vehicule?: string | null;
  depart: string;
  depart_lat: number;
  depart_lng: number;
  destination: string;
  destination_lat: number;
  destination_lng: number;
  distance_km: number;
  cout_total?: number;
  prix_par_place: number;
  date_heure_depart: string;
  places_disponibles: number;
  places_restantes?: number;
  description?: string;
  est_regulier?: boolean;
  jours_semaine?: string[] | null;
  statut: "ouvert" | "en_cours" | "termine" | "annule";
  created_at?: string;
}

export interface PositionActuelleResponse {
  trajet_id?: number;
  position?: PositionGPS;
  suivi?: SuiviInfo;
  suivi_info?: SuiviInfo;
  latitude?: number;
  longitude?: number;
  vitesse_kmh?: number;
  [key: string]: any;
}

export interface PositionMiseAJourData {
  latitude: number;
  longitude: number;
  altitude?: number;
  precision?: number;
  vitesse_kmh?: number;
  direction?: number;
}
