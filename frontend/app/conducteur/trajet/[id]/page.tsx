'use client';

import { useEffect, useState, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft,
  Play,
  Square,
  Navigation,
  AlertTriangle,
  CheckCircle,
  Wifi,
  WifiOff,
} from 'lucide-react';
import Link from 'next/link';

import CarteTrajet from '@/components/CarteTrajet';
import InfoSuivi from '@/components/InfoSuivi';
import trajetApi from '@/libs/trajet-api';
import { useTrajetWebSocket } from '@/src/hooks/useTrajetWebSocket';
import { Trajet, PositionActuelleResponse, PositionMiseAJourData } from '@/types/trajet';

export default function GestionTrajetPage() {
  const params = useParams();
  const router = useRouter();
  const trajetId = params.id as string;

  const [trajet, setTrajet] = useState<Trajet | null>(null);
  const [positionData, setPositionData] = useState<PositionActuelleResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [gpsTracking, setGpsTracking] = useState(false);
  const [watchId, setWatchId] = useState<number | null>(null);

  // WebSocket GPS — connexion automatique dès que le trajetId est connu
  const { isConnected: wsConnected, sendPosition } = useTrajetWebSocket({
    trajetId: trajet?.statut === 'en_cours' ? trajetId : null,
  });

  // Charger les informations du trajet
  const loadTrajet = async () => {
    try {
      const trajetData = await trajetApi.getTrajet(trajetId);
      setTrajet(trajetData);

      // Vérifier si l'utilisateur est bien le conducteur
      // Note: Cette vérification devrait être faite côté backend, mais on ajoute une vérification de base
      if (typeof window !== 'undefined') {
        const userStr = localStorage.getItem('user');
        if (userStr) {
          const user = JSON.parse(userStr);
          if (trajetData.conducteur !== user.id) {
            setError("Vous n'êtes pas le conducteur de ce trajet");
            return;
          }
        }
      }

      // Si le trajet est en cours, démarrer le suivi GPS
      if (trajetData.statut === 'en_cours') {
        startGpsTracking();
      }
    } catch (err: any) {
      if (err.response?.status === 404) {
        setError('Trajet non trouvé');
      } else if (err.response?.status === 403) {
        setError('Accès non autorisé');
      } else {
        setError(err.response?.data?.error || 'Impossible de charger les informations du trajet');
      }
    }
  };

  // Charger la position actuelle
  const loadPosition = async () => {
    try {
      const positionResponse = await trajetApi.getPositionActuelle(trajetId);
      setPositionData(positionResponse);
    } catch (err: any) {
      // Ne pas afficher d'erreur si le trajet n'est pas en cours
      // Silencieux si le trajet n'est pas en cours (400)
    }
  };

  // Démarrer le trajet
  const commencerTrajet = async () => {
    setActionLoading(true);
    setError(null);

    try {
      const response = await trajetApi.commencerTrajet(trajetId);
      setTrajet(response.trajet);
      setSuccessMessage(response.message);

      // Démarrer le suivi GPS
      startGpsTracking();

      // Charger la position initiale
      setTimeout(() => {
        loadPosition();
      }, 1000);

    } catch (err: any) {
      setError(err.response?.data?.error || 'Impossible de démarrer le trajet');
    } finally {
      setActionLoading(false);
    }
  };

  // Terminer le trajet
  const terminerTrajet = async () => {
    setActionLoading(true);
    setError(null);

    try {
      const response = await trajetApi.terminerTrajet(trajetId);
      setTrajet(response.trajet);
      setSuccessMessage(response.message);

      // Arrêter le suivi GPS
      stopGpsTracking();

    } catch (err: any) {
      setError(err.response?.data?.error || 'Impossible de terminer le trajet');
    } finally {
      setActionLoading(false);
    }
  };

  // Démarrer le suivi GPS
  const startGpsTracking = () => {
    if (!navigator.geolocation) {
      setError('La géolocalisation n\'est pas supportée par votre navigateur');
      return;
    }

    setGpsTracking(true);

    const id = navigator.geolocation.watchPosition(
      (position) => {
        const pos = {
          latitude:    position.coords.latitude,
          longitude:   position.coords.longitude,
          vitesse_kmh: position.coords.speed != null ? position.coords.speed * 3.6 : undefined,
          direction:   position.coords.heading ?? undefined,
        };

        // Priorité : WebSocket (temps réel) → fallback REST
        if (wsConnected) {
          sendPosition(pos);
          // Mettre à jour l'état local immédiatement
          setPositionData({
            position: pos,
            latitude: pos.latitude,
            longitude: pos.longitude,
          });
        } else {
          trajetApi.mettreAJourPosition(trajetId, {
            ...pos,
            altitude: position.coords.altitude ?? undefined,
          }).catch(() => {});
        }
      },
      (error) => {
        setError('Erreur de géolocalisation: ' + error.message);
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
      }
    );

    setWatchId(id);
  };

  // Arrêter le suivi GPS
  const stopGpsTracking = () => {
    if (watchId !== null) {
      navigator.geolocation.clearWatch(watchId);
      setWatchId(null);
    }
    setGpsTracking(false);
  };

  // Charger les données au montage
  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await loadTrajet();
      await loadPosition();
      setLoading(false);
    };

    if (trajetId) {
      loadData();
    }

    // Nettoyer le suivi GPS au démontage
    return () => {
      stopGpsTracking();
    };
  }, [trajetId]);

  // Rafraîchissement automatique de la position toutes les 30 secondes
  useEffect(() => {
    if (trajet?.statut !== 'en_cours') return;

    const interval = setInterval(() => {
      loadPosition();
    }, 30000); // 30 secondes

    return () => clearInterval(interval);
  }, [trajet?.statut, trajetId]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Chargement des informations du trajet...</p>
        </div>
      </div>
    );
  }

  if (error && !trajet) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center max-w-md mx-auto p-6">
          <AlertTriangle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-800 mb-2">Erreur</h1>
          <p className="text-gray-600 mb-4">{error}</p>
          {error.includes('non trouvé') && (
            <p className="text-sm text-gray-500 mb-6">
              Le trajet que vous essayez d'accéder n'existe pas ou a été supprimé.
            </p>
          )}
          <Link
            href="/conducteur/trajets"
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            Retour à mes trajets
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* En-tête */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <Link
                href="/conducteur/trajets"
                className="inline-flex items-center text-gray-600 hover:text-gray-900 mr-4"
              >
                <ArrowLeft className="w-5 h-5 mr-2" />
                Retour
              </Link>
              <h1 className="text-xl font-semibold text-gray-900">
                Gestion du trajet
              </h1>
            </div>

            {/* Indicateurs GPS + WebSocket */}
            <div className="flex items-center gap-3">
              {wsConnected ? (
                <div className="flex items-center gap-1.5 text-green-600 text-sm font-medium">
                  <Wifi className="w-4 h-4" />
                  <span>Temps réel</span>
                </div>
              ) : (
                <div className="flex items-center gap-1.5 text-gray-400 text-sm">
                  <WifiOff className="w-4 h-4" />
                  <span>Hors ligne</span>
                </div>
              )}
              {gpsTracking && (
                <div className="flex items-center gap-1.5 text-green-600 text-sm font-medium">
                  <Navigation className="w-4 h-4 animate-pulse" />
                  <span>GPS actif</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Messages */}
      {successMessage && (
        <div className="bg-green-50 border border-green-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex items-center">
              <CheckCircle className="w-5 h-5 text-green-600 mr-2" />
              <p className="text-green-800">{successMessage}</p>
            </div>
          </div>
        </div>
      )}

      {error && (
        <div className="bg-red-50 border border-red-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex items-center">
              <AlertTriangle className="w-5 h-5 text-red-600 mr-2" />
              <p className="text-red-800">{error}</p>
            </div>
          </div>
        </div>
      )}

      {/* Contenu principal */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {trajet && (
          <>
            {/* Informations du trajet */}
            <div className="mb-6">
              <div className="bg-white rounded-lg shadow-sm p-6">
                <h2 className="text-lg font-semibold text-gray-800 mb-4">
                  Détails du trajet
                </h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div>
                    <p className="text-sm text-gray-600">Trajet</p>
                    <p className="font-medium">{trajet.depart} → {trajet.destination}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Date et heure</p>
                    <p className="font-medium">
                      {new Date(trajet.date_heure_depart).toLocaleDateString('fr-FR', {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Places</p>
                    <p className="font-medium">{trajet.places_restantes}/{trajet.places_disponibles} disponibles</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Statut</p>
                    <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${trajet.statut === 'en_cours' ? 'bg-green-100 text-green-800' :
                      trajet.statut === 'termine' ? 'bg-gray-100 text-gray-800' :
                        trajet.statut === 'ouvert' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-red-100 text-red-800'
                      }`}>
                      {trajet.statut === 'en_cours' ? 'En cours' :
                        trajet.statut === 'termine' ? 'Terminé' :
                          trajet.statut === 'ouvert' ? 'Ouvert' :
                            'Annulé'}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Actions du conducteur */}
            <div className="mb-6">
              <div className="bg-white rounded-lg shadow-sm p-6">
                <h3 className="text-lg font-semibold text-gray-800 mb-4">
                  Actions du conducteur
                </h3>

                {trajet.statut === 'ouvert' && (
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="font-medium text-gray-800">Prêt à commencer le trajet ?</p>
                      <p className="text-sm text-gray-600">
                        Cliquez sur le bouton ci-dessous pour démarrer le suivi GPS et informer les passagers.
                      </p>
                    </div>
                    <button
                      onClick={commencerTrajet}
                      disabled={actionLoading}
                      className="inline-flex items-center px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
                    >
                      <Play className="w-5 h-5 mr-2" />
                      {actionLoading ? 'Démarrage...' : 'Commencer le trajet'}
                    </button>
                  </div>
                )}

                {trajet.statut === 'en_cours' && (
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="font-medium text-gray-800">Trajet en cours</p>
                      <p className="text-sm text-gray-600">
                        Le suivi GPS est actif. Cliquez sur le bouton ci-dessous pour terminer le trajet.
                      </p>
                    </div>
                    <button
                      onClick={terminerTrajet}
                      disabled={actionLoading}
                      className="inline-flex items-center px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 transition-colors"
                    >
                      <Square className="w-5 h-5 mr-2" />
                      {actionLoading ? 'Arrêt...' : 'Terminer le trajet'}
                    </button>
                  </div>
                )}

                {trajet.statut === 'termine' && (
                  <div className="text-center py-4">
                    <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
                    <p className="text-lg font-medium text-gray-800">Trajet terminé</p>
                    <p className="text-sm text-gray-600">
                      Le trajet a été terminé avec succès. Les passagers ont été notifiés.
                    </p>
                  </div>
                )}
              </div>
            </div>

            {/* Carte et informations de suivi */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Carte */}
              <div className="lg:col-span-2">
                <div className="bg-white rounded-lg shadow-sm p-6">
                  <h3 className="text-lg font-semibold text-gray-800 mb-4">
                    Carte de suivi
                  </h3>
                  <CarteTrajet
                    positionActuelle={positionData?.position}
                    departLat={trajet.depart_lat}
                    departLng={trajet.depart_lng}
                    destinationLat={trajet.destination_lat}
                    destinationLng={trajet.destination_lng}
                    suiviInfo={positionData?.suivi}
                    className="h-96 w-full"
                  />
                </div>
              </div>

              {/* Informations de suivi */}
              <div className="lg:col-span-1">
                <InfoSuivi
                  positionActuelle={positionData?.position}
                  suiviInfo={positionData?.suivi}
                  statutTrajet={trajet.statut}
                />
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
