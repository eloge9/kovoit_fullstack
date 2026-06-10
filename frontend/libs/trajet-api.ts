import axios from 'axios';
import { Trajet } from '@/src/services/trajet.service';

// Types définis localement pour l'API
interface TrajetActionResponse {
  message: string;
  trajet: Trajet;
}

interface PositionActuelleResponse {
  latitude: number;
  longitude: number;
  vitesse_kmh?: number;
  direction?: number;
  timestamp?: string;
  derniere_mise_a_jour?: string;
}

interface PositionMiseAJourData {
  latitude: number;
  longitude: number;
  altitude?: number;
  precision?: number;
  vitesse_kmh?: number;
  direction?: number;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000/api';

// Créer une instance axios avec le token d'authentification
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Intercepteur pour ajouter le token d'authentification
apiClient.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

export const trajetApi = {
  // Démarrer un trajet (alias vers commencer_trajet/ — endpoint dédié avec retour trajet)
  commencerTrajet: async (trajetId: string): Promise<TrajetActionResponse> => {
    const response = await apiClient.post(`/trajets/${trajetId}/commencer_trajet/`);
    return response.data;
  },

  // Terminer un trajet (alias vers terminer_trajet/ — endpoint dédié avec retour trajet)
  terminerTrajet: async (trajetId: string): Promise<TrajetActionResponse> => {
    const response = await apiClient.post(`/trajets/${trajetId}/terminer_trajet/`);
    return response.data;
  },

  // Mettre à jour la position GPS (fallback REST si WebSocket indisponible)
  mettreAJourPosition: async (trajetId: string, positionData: PositionMiseAJourData): Promise<any> => {
    const response = await apiClient.post(`/trajets/${trajetId}/mettre_a_jour_position/`, positionData);
    return response.data;
  },

  // Obtenir la dernière position GPS connue (fallback REST)
  getPositionActuelle: async (trajetId: string): Promise<PositionActuelleResponse> => {
    const response = await apiClient.get(`/trajets/${trajetId}/position_actuelle/`);
    return response.data;
  },

  // Obtenir les détails d'un trajet
  getTrajet: async (trajetId: string): Promise<Trajet> => {
    const response = await apiClient.get(`/trajets/${trajetId}/`);
    return response.data;
  },

  // Obtenir les trajets du conducteur
  getMesTrajets: async (): Promise<Trajet[]> => {
    const response = await apiClient.get('/trajets/mes_trajets/');
    return response.data;
  },

  // Obtenir tous les trajets ouverts
  getTrajetsOuverts: async (): Promise<Trajet[]> => {
    const response = await apiClient.get('/trajets/');
    return response.data;
  },

  // Rechercher des trajets
  rechercherTrajets: async (params: {
    depart?: string;
    destination?: string;
    date?: string;
    places?: number;
    type_vehicule?: string;
  }): Promise<Trajet[]> => {
    const response = await apiClient.get('/trajets/rechercher/', { params });
    return response.data;
  },

  // Obtenir les réservations d'un trajet spécifique
  getReservationsTrajet: async (trajetId: string): Promise<any[]> => {
    const response = await apiClient.get('/reservations/recues/');
    console.log('Réservations reçues:', response.data);
    // Filtrer pour ne retourner que les réservations du trajet spécifié
    const filtered = response.data.filter((res: any) => res.trajet_id === parseInt(trajetId));
    console.log('Réservations filtrées:', filtered);
    return filtered;
  },
};

export default trajetApi;
