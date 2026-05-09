'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { ArrowLeft, RefreshCw, AlertTriangle } from 'lucide-react';
import Link from 'next/link';

import CarteTrajet from '@/components/CarteTrajet';
import InfoSuivi from '@/components/InfoSuivi';
import trajetApi from '@/libs/trajet-api';
import { Trajet, PositionActuelleResponse } from '@/types/trajet';

export default function SuiviTrajetPage() {
  const params = useParams();
  const router = useRouter();
  const trajetId = params.id as string;

  const [trajet, setTrajet] = useState<Trajet | null>(null);
  const [positionData, setPositionData] = useState<PositionActuelleResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  // Charger les informations du trajet
  const loadTrajet = async () => {
    try {
      const trajetData = await trajetApi.getTrajet(trajetId);
      setTrajet(trajetData);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Impossible de charger les informations du trajet');
    }
  };

  // Charger la position actuelle
  const loadPosition = async () => {
    try {
      const positionResponse = await trajetApi.getPositionActuelle(trajetId);
      setPositionData(positionResponse);
      setError(null);
    } catch (err: any) {
      if (err.response?.status === 400) {
        setError(err.response.data.error || 'Ce trajet n\'est pas en cours');
      } else if (err.response?.status === 404) {
        setError('Aucune position GPS disponible pour le moment');
      } else {
        setError('Impossible de charger la position actuelle');
      }
    }
  };

  // Rafraîchir les données
  const refreshData = async () => {
    setRefreshing(true);
    await Promise.all([loadTrajet(), loadPosition()]);
    setRefreshing(false);
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
  }, [trajetId]);

  // Rafraîchissement automatique toutes les 30 secondes
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
          <p className="text-gray-600">Chargement des informations de suivi...</p>
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
          <p className="text-gray-600 mb-6">{error}</p>
          <Link
            href="/passager/mes-reservations"
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            Retour à mes réservations
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
                href="/passager/mes-reservations"
                className="inline-flex items-center text-gray-600 hover:text-gray-900 mr-4"
              >
                <ArrowLeft className="w-5 h-5 mr-2" />
                Retour
              </Link>
              <h1 className="text-xl font-semibold text-gray-900">
                Suivi du trajet
              </h1>
            </div>
            <button
              onClick={refreshData}
              disabled={refreshing}
              className="inline-flex items-center px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
              {refreshing ? 'Actualisation...' : 'Actualiser'}
            </button>
          </div>
        </div>
      </div>

      {/* Contenu principal */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {trajet && (
          <div className="mb-6">
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-lg font-semibold text-gray-800 mb-4">
                Détails du trajet
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div>
                  <p className="text-sm text-gray-600">Conducteur</p>
                  <p className="font-medium">{trajet.conducteur_nom}</p>
                  <p className="text-sm text-gray-500">Note: {trajet.conducteur_note}/5</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Trajet</p>
                  <p className="font-medium">{trajet.depart} → {trajet.destination}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Véhicule</p>
                  <p className="font-medium">
                    {trajet.vehicule_info ?
                      `${trajet.vehicule_info.marque} ${trajet.vehicule_info.modele}` :
                      'Non spécifié'
                    }
                  </p>
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
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Carte */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h3 className="text-lg font-semibold text-gray-800 mb-4">
                Carte de suivi
              </h3>
              <CarteTrajet
                positionActuelle={positionData?.position}
                departLat={trajet?.depart_lat}
                departLng={trajet?.depart_lng}
                destinationLat={trajet?.destination_lat}
                destinationLng={trajet?.destination_lng}
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
              statutTrajet={trajet?.statut}
            />
          </div>
        </div>

        {/* Message d'erreur ou d'information */}
        {error && (
          <div className="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div className="flex items-center">
              <AlertTriangle className="w-5 h-5 text-yellow-600 mr-2" />
              <p className="text-yellow-800">{error}</p>
            </div>
          </div>
        )}

        {/* Instructions */}
        {trajet?.statut === 'ouvert' && (
          <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h3 className="font-medium text-blue-800 mb-2">Le trajet n'a pas encore commencé</h3>
            <p className="text-blue-700">
              Le conducteur n'a pas encore démarré le trajet. La carte de suivi sera disponible
              dès que le trajet commencera. Vous pouvez actualiser cette page pour vérifier
              le statut du trajet.
            </p>
          </div>
        )}

        {trajet?.statut === 'termine' && (
          <div className="mt-6 bg-green-50 border border-green-200 rounded-lg p-4">
            <h3 className="font-medium text-green-800 mb-2">Trajet terminé</h3>
            <p className="text-green-700">
              Le trajet est terminé. Vous pouvez maintenant procéder au paiement si ce n'est pas déjà fait.
            </p>
            <Link
              href="/passager/paiements"
              className="inline-flex items-center mt-3 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              Voir mes paiements
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
