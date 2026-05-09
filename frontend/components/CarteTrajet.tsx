'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import { PositionGPS, SuiviInfo } from '@/types/trajet';

// Import dynamique de Leaflet pour éviter les erreurs SSR
const MapContainer = dynamic(() => import('react-leaflet').then(mod => mod.MapContainer), { ssr: false });
const TileLayer = dynamic(() => import('react-leaflet').then(mod => mod.TileLayer), { ssr: false });
const Marker = dynamic(() => import('react-leaflet').then(mod => mod.Marker), { ssr: false });
const Popup = dynamic(() => import('react-leaflet').then(mod => mod.Popup), { ssr: false });
const Polyline = dynamic(() => import('react-leaflet').then(mod => mod.Polyline), { ssr: false });

interface CarteTrajetProps {
  positionActuelle?: PositionGPS;
  departLat?: number;
  departLng?: number;
  destinationLat?: number;
  destinationLng?: number;
  suiviInfo?: SuiviInfo;
  className?: string;
}

export default function CarteTrajet({
  positionActuelle,
  departLat,
  departLng,
  destinationLat,
  destinationLng,
  suiviInfo,
  className = "h-96 w-full"
}: CarteTrajetProps) {
  const [L, setL] = useState<any>(null);
  const [map, setMap] = useState<any>(null);

  useEffect(() => {
    // Importer Leaflet uniquement côté client
    import('leaflet').then((leaflet) => {
      // Corriger les icônes par défaut
      delete (leaflet.Icon.Default.prototype as any)._getIconUrl;
      leaflet.Icon.Default.mergeOptions({
        iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
        iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
        shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
      });
      setL(leaflet);
    });
  }, []);

  useEffect(() => {
    if (L && map && positionActuelle) {
      // Centrer la carte sur la position actuelle
      map.setView([positionActuelle.latitude, positionActuelle.longitude], 13);
    }
  }, [L, map, positionActuelle]);

  if (!L) {
    return (
      <div className={`${className} bg-gray-200 flex items-center justify-center`}>
        <div className="text-gray-500">Chargement de la carte...</div>
      </div>
    );
  }

  // Déterminer le centre de la carte
  let centerLat = 6.5; // Par défaut: centre du Bénin
  let centerLng = 2.5;

  if (positionActuelle) {
    centerLat = positionActuelle.latitude;
    centerLng = positionActuelle.longitude;
  } else if (departLat && departLng) {
    centerLat = departLat;
    centerLng = departLng;
  }

  // Créer les points pour la polyline
  const routePoints: [number, number][] = [];

  if (departLat && departLng) {
    routePoints.push([departLat, departLng]);
  }

  if (positionActuelle) {
    routePoints.push([positionActuelle.latitude, positionActuelle.longitude]);
  }

  if (destinationLat && destinationLng) {
    routePoints.push([destinationLat, destinationLng]);
  }

  return (
    <div className={className}>
      <MapContainer
        center={[centerLat, centerLng]}
        zoom={13}
        className={className}
        ref={setMap}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* Marqueur de départ */}
        {departLat && departLng && (
          <Marker position={[departLat, departLng]}>
            <Popup>
              <div className="text-sm">
                <strong>Point de départ</strong>
                <br />
                Début du trajet
              </div>
            </Popup>
          </Marker>
        )}

        {/* Marqueur de position actuelle */}
        {positionActuelle && (
          <Marker position={[positionActuelle.latitude, positionActuelle.longitude]}>
            <Popup>
              <div className="text-sm">
                <strong>Position actuelle</strong>
                <br />
                Vitesse: {positionActuelle.vitesse_kmh ? `${positionActuelle.vitesse_kmh} km/h` : 'N/A'}
                <br />
                Direction: {positionActuelle.direction ? `${positionActuelle.direction}°` : 'N/A'}
                <br />
                {suiviInfo && (
                  <>
                    Temps restant: {suiviInfo.temps_restant_minutes ? `${Math.round(suiviInfo.temps_restant_minutes)} min` : 'N/A'}
                    <br />
                    Distance restante: {suiviInfo.distance_restante_km ? `${suiviInfo.distance_restante_km} km` : 'N/A'}
                  </>
                )}
              </div>
            </Popup>
          </Marker>
        )}

        {/* Marqueur de destination */}
        {destinationLat && destinationLng && (
          <Marker position={[destinationLat, destinationLng]}>
            <Popup>
              <div className="text-sm">
                <strong>Destination</strong>
                <br />
                Point d'arrivée
              </div>
            </Popup>
          </Marker>
        )}

        {/* Ligne de route */}
        {routePoints.length > 1 && (
          <Polyline
            positions={routePoints}
            color="blue"
            weight={3}
            opacity={0.7}
          />
        )}
      </MapContainer>
    </div>
  );
}
