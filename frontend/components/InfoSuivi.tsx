'use client';

import { Clock, MapPin, Navigation, AlertCircle } from 'lucide-react';
import { SuiviInfo, PositionGPS } from '@/types/trajet';

interface InfoSuiviProps {
  positionActuelle?: PositionGPS;
  suiviInfo?: SuiviInfo;
  statutTrajet?: string;
  className?: string;
}

export default function InfoSuivi({
  positionActuelle,
  suiviInfo,
  statutTrajet,
  className = ""
}: InfoSuiviProps) {
  const formatTime = (dateString?: string) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  return (
    <div className={`bg-white rounded-lg shadow-md p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4 text-gray-800">
        Informations de suivi
      </h3>

      {/* Statut du trajet */}
      <div className="mb-4">
        <div className="flex items-center space-x-2">
          <AlertCircle className={`w-5 h-5 ${statutTrajet === 'en_cours' ? 'text-green-500' :
              statutTrajet === 'termine' ? 'text-gray-500' :
                'text-yellow-500'
            }`} />
          <span className={`font-medium ${statutTrajet === 'en_cours' ? 'text-green-600' :
              statutTrajet === 'termine' ? 'text-gray-600' :
                'text-yellow-600'
            }`}>
            {statutTrajet === 'en_cours' ? 'Trajet en cours' :
              statutTrajet === 'termine' ? 'Trajet terminé' :
                statutTrajet === 'ouvert' ? 'Trajet ouvert' :
                  'Trajet annulé'}
          </span>
        </div>
      </div>

      {/* Position actuelle */}
      {positionActuelle && (
        <div className="space-y-3 mb-4">
          <div className="flex items-center space-x-3">
            <MapPin className="w-5 h-5 text-blue-500" />
            <div>
              <p className="text-sm text-gray-600">Position actuelle</p>
              <p className="font-mono text-sm">
                {positionActuelle.latitude.toFixed(6)}, {positionActuelle.longitude.toFixed(6)}
              </p>
            </div>
          </div>

          {positionActuelle.vitesse_kmh && (
            <div className="flex items-center space-x-3">
              <Navigation className="w-5 h-5 text-green-500" />
              <div>
                <p className="text-sm text-gray-600">Vitesse</p>
                <p className="font-semibold">{positionActuelle.vitesse_kmh} km/h</p>
              </div>
            </div>
          )}

          {positionActuelle.direction && (
            <div className="flex items-center space-x-3">
              <Navigation className="w-5 h-5 text-purple-500" />
              <div>
                <p className="text-sm text-gray-600">Direction</p>
                <p className="font-semibold">{positionActuelle.direction}°</p>
              </div>
            </div>
          )}

          <div className="flex items-center space-x-3">
            <Clock className="w-5 h-5 text-gray-500" />
            <div>
              <p className="text-sm text-gray-600">Dernière mise à jour</p>
              <p className="font-semibold">{formatTime(positionActuelle.timestamp)}</p>
            </div>
          </div>
        </div>
      )}

      {/* Informations de suivi */}
      {suiviInfo && (
        <div className="border-t pt-4 space-y-3">
          <h4 className="font-medium text-gray-800 mb-2">Estimation d'arrivée</h4>

          {suiviInfo.temps_restant_minutes && (
            <div className="flex items-center space-x-3">
              <Clock className="w-5 h-5 text-orange-500" />
              <div>
                <p className="text-sm text-gray-600">Temps restant</p>
                <p className="font-semibold text-lg">
                  {Math.round(suiviInfo.temps_restant_minutes)} minutes
                </p>
              </div>
            </div>
          )}

          {suiviInfo.distance_restante_km && (
            <div className="flex items-center space-x-3">
              <MapPin className="w-5 h-5 text-red-500" />
              <div>
                <p className="text-sm text-gray-600">Distance restante</p>
                <p className="font-semibold text-lg">
                  {suiviInfo.distance_restante_km} km
                </p>
              </div>
            </div>
          )}

          {suiviInfo.heure_arrivee_estimee && (
            <div className="flex items-center space-x-3">
              <Clock className="w-5 h-5 text-green-500" />
              <div>
                <p className="text-sm text-gray-600">Heure d'arrivée estimée</p>
                <p className="font-semibold">
                  {formatDate(suiviInfo.heure_arrivee_estimee)}
                </p>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Message si pas de position */}
      {!positionActuelle && (
        <div className="text-center py-8 text-gray-500">
          <MapPin className="w-12 h-12 mx-auto mb-3 text-gray-300" />
          <p>Aucune position GPS disponible</p>
          <p className="text-sm">Le trajet n'a pas encore commencé ou le GPS n'est pas activé</p>
        </div>
      )}
    </div>
  );
}
