import json
import math

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser

# ── Cache en mémoire ──────────────────────────────────────────────────────────
# Phase 2 : migrer vers Redis pour multi-worker
_derniere_position: dict = {}   # {trajet_id: payload conducteur}
_positions_passagers: dict = {} # {trajet_id: {str(user_id): {lat, lng, nom, ...}}}

WS_FORBIDDEN   = 4003
WS_BAD_REQUEST = 4400
SEUIL_ARRIVEE_M = 80  # Détection arrivée conducteur chez passager


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance en mètres entre deux coordonnées GPS (formule Haversine)."""
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = (math.sin(dphi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class GpsConsumer(AsyncWebsocketConsumer):
    """
    WebSocket de suivi GPS temps réel.

    Conducteur → envoie 'position' ou 'location_update' (compatibilité mobile).
    Passager   → envoie 'passenger_position' (sa propre position GPS).
    Tous       → reçoivent position_update, passenger_position, driver_arrived.
    Condition  → trajet au statut 'en_cours', passager doit avoir réservation confirmée.
    """

    @database_sync_to_async
    def _verifier_acces(self, user, trajet_id: str):
        from apps.modeles.models import Trajet, Reservation

        if not user or isinstance(user, AnonymousUser) or not user.is_authenticated:
            return None, None, None

        try:
            trajet = Trajet.objects.select_related("conducteur").get(pk=trajet_id)
        except (Trajet.DoesNotExist, ValueError):
            return None, None, None

        if trajet.statut != "en_cours":
            return None, None, None

        if trajet.conducteur_id == user.pk:
            return "conducteur", trajet, user

        est_passager = Reservation.objects.filter(
            trajet=trajet,
            passager=user,
            statut="confirmee",
        ).exists()
        if est_passager:
            return "passager", trajet, user

        return None, None, None

    @staticmethod
    def _coords_valides(lat, lng):
        try:
            lat, lng = float(lat), float(lng)
        except (TypeError, ValueError):
            return None
        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return None
        return lat, lng

    # ── Cycle de vie ──────────────────────────────────────────────────────────

    async def connect(self):
        self.trajet_id = self.scope["url_route"]["kwargs"].get("trajet_id")
        self.user      = self.scope.get("user")
        self.role_ws   = None
        self.user_id   = None
        self.user_nom  = ""

        role, _trajet, user = await self._verifier_acces(self.user, self.trajet_id)
        if role is None:
            await self.close(code=WS_FORBIDDEN)
            return

        self.role_ws  = role
        self.user_id  = str(user.pk)
        self.user_nom = (
            f"{user.first_name} {user.last_name}".strip() or user.username
        )
        self.room = f"trajet_{self.trajet_id}"

        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()

        # Envoyer dernière position conducteur immédiatement si disponible
        if self.trajet_id in _derniere_position:
            await self.send(text_data=json.dumps(_derniere_position[self.trajet_id]))

        # Conducteur : envoyer les positions passagers déjà connues
        if role == "conducteur" and self.trajet_id in _positions_passagers:
            for pdata in _positions_passagers[self.trajet_id].values():
                payload = {k: v for k, v in pdata.items() if k != "conducteur_arrive"}
                await self.send(text_data=json.dumps({
                    "type": "passenger_position",
                    **payload,
                }))

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.close(code=WS_BAD_REQUEST)
            return

        msg_type = data.get("type", "")

        # ── Conducteur → broadcast position ───────────────────────────────────
        if self.role_ws == "conducteur" and msg_type in ("position", "location_update"):
            coords = self._coords_valides(
                data.get("latitude"), data.get("longitude")
            )
            if coords is None:
                return
            lat, lng = coords

            try:
                if msg_type == "location_update":
                    # Mobile envoie speed en m/s dans ce type de message
                    raw = float(data.get("speed", 0) or 0)
                    vitesse_kmh = max(0.0, raw * 3.6)
                else:
                    vitesse_kmh = max(0.0, float(data.get("vitesse_kmh", 0) or 0))
            except (TypeError, ValueError):
                vitesse_kmh = 0.0

            payload = {
                "type":        "position_update",
                "latitude":    lat,
                "longitude":   lng,
                "vitesse_kmh": round(vitesse_kmh, 1),
                "heading":     data.get("heading"),
                "timestamp":   data.get("timestamp"),
            }
            _derniere_position[self.trajet_id] = payload
            await self.channel_layer.group_send(self.room, payload)
            await self._check_driver_arrived(lat, lng)

        # ── Passager → broadcast sa position ─────────────────────────────────
        elif self.role_ws == "passager" and msg_type == "passenger_position":
            coords = self._coords_valides(
                data.get("latitude"), data.get("longitude")
            )
            if coords is None:
                return
            lat, lng = coords

            nom = data.get("nom") or self.user_nom

            pdata = {
                "user_id":   self.user_id,
                "nom":       nom,
                "latitude":  lat,
                "longitude": lng,
                "timestamp": data.get("timestamp"),
            }

            # Stocker en cache (préserver le flag conducteur_arrive)
            if self.trajet_id not in _positions_passagers:
                _positions_passagers[self.trajet_id] = {}
            existing = _positions_passagers[self.trajet_id].get(self.user_id, {})
            _positions_passagers[self.trajet_id][self.user_id] = {
                **pdata,
                "conducteur_arrive": existing.get("conducteur_arrive", False),
            }

            # Diffuser à toute la room (conducteur voit les passagers)
            await self.channel_layer.group_send(self.room, {
                "type": "passenger_position",
                **pdata,
            })

    async def _check_driver_arrived(self, driver_lat: float, driver_lng: float):
        """Diffuse driver_arrived si le conducteur est à ≤ 80m d'un passager."""
        passagers = _positions_passagers.get(self.trajet_id, {})
        for uid, pdata in passagers.items():
            p_lat = pdata.get("latitude")
            p_lng = pdata.get("longitude")
            if p_lat is None or pdata.get("conducteur_arrive"):
                continue
            dist = _haversine_m(driver_lat, driver_lng, p_lat, p_lng)
            if dist <= SEUIL_ARRIVEE_M:
                _positions_passagers[self.trajet_id][uid]["conducteur_arrive"] = True
                await self.channel_layer.group_send(self.room, {
                    "type":       "driver_arrived",
                    "user_id":    uid,
                    "nom":        pdata.get("nom", ""),
                    "distance_m": round(dist),
                })

    # ── Handlers group_send ───────────────────────────────────────────────────

    async def position_update(self, event):
        await self.send(text_data=json.dumps(event))

    async def passenger_position(self, event):
        await self.send(text_data=json.dumps(event))

    async def driver_arrived(self, event):
        await self.send(text_data=json.dumps(event))
