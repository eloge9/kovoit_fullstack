import hmac as hmac_lib
import hashlib
import logging
import time
import math
from datetime import timedelta

logger = logging.getLogger(__name__)

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import NotFound, PermissionDenied
from django.db import transaction
from django.db.models import Q
from django.conf import settings
from django.utils import timezone
from ..modeles.models import Reservation, Trajet, BlocagePassager
from .serializers import ReservationSerializer, ReservationCreateSerializer

PENALITE_ANNULATION_TARDIVE = 0.20  # 20% du prix si annulation < 2h avant départ


class ReservationViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    def get_object(self):
        pk = self.kwargs.get('pk')
        try:
            # Filtre propriétaire dans la même requête DB :
            # même réponse 404 que la réservation n'existe pas ou n'appartienne pas à l'user.
            # Évite le timing-leak qui révèle l'existence d'une ressource (IDOR).
            return Reservation.objects.select_related(
                'trajet', 'trajet__conducteur', 'passager'
            ).get(
                Q(passager=self.request.user) | Q(trajet__conducteur=self.request.user),
                pk=pk,
            )
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable.")

    def retrieve(self, request, pk=None):
        reservation = self.get_object()
        serializer = ReservationSerializer(reservation)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def reserver(self, request):
        serializer = ReservationCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        trajet_id = serializer.validated_data['trajet_id']

        # CORRECTION RACE CONDITION : Verrouillage de la ligne en base pour la durée de la transaction
        with transaction.atomic():
            try:
                trajet = Trajet.objects.select_for_update().get(pk=trajet_id, statut='ouvert')
            except Trajet.DoesNotExist:
                return Response({"error": "Trajet introuvable ou non disponible."}, status=404)

            if trajet.conducteur == request.user:
                return Response({"error": "Vous ne pouvez pas réserver votre propre trajet."}, status=400)

            # Vérifier que le conducteur n'a pas bloqué ce passager
            if BlocagePassager.objects.filter(conducteur=trajet.conducteur, passager=request.user).exists():
                return Response({"error": "Vous n'êtes pas autorisé à réserver ce trajet."}, status=403)

            if Reservation.objects.filter(trajet=trajet, passager=request.user, statut__in=['en_attente', 'confirmee']).exists():
                return Response({"error": "Vous avez déjà une réservation active pour ce trajet."}, status=400)

            # Recalculer le nombre de places confirmées DANS la transaction verrouillée
            nb_confirmees = trajet.reservations.filter(statut='confirmee').count()
            if nb_confirmees >= trajet.places_disponibles:
                return Response({"error": "Plus de places disponibles."}, status=400)

            vd = serializer.validated_data
            pickup_lat = vd.get('prise_en_charge_lat')
            pickup_lng = vd.get('prise_en_charge_lng')
            dropoff_lat = vd.get('depose_lat')
            dropoff_lng = vd.get('depose_lng')

            # Calcul du prix par km selon le type de véhicule
            prix_passager = None
            distance_passager = None
            if all([pickup_lat, pickup_lng, dropoff_lat, dropoff_lng]):
                try:
                    from apps.trajets.matching import (
                        calculer_score_matching_v2, calculer_prix_par_km,
                    )
                    match = calculer_score_matching_v2(
                        trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                    )
                    distance_passager = match['distance_passager_km']
                    type_vehicule = ''
                    try:
                        type_vehicule = str(trajet.vehicule.type_vehicule or '').lower()
                    except AttributeError:
                        pass
                    places = max(1, int(trajet.places_disponibles or 1))
                    prix_passager = calculer_prix_par_km(distance_passager, type_vehicule, places)
                except Exception:
                    pass

            reservation = Reservation.objects.create(
                trajet=trajet,
                passager=request.user,
                statut='en_attente',
                point_prise_en_charge=vd.get('point_prise_en_charge', ''),
                prise_en_charge_lat=pickup_lat,
                prise_en_charge_lng=pickup_lng,
                point_depose=vd.get('point_depose', ''),
                depose_lat=dropoff_lat,
                depose_lng=dropoff_lng,
                distance_passager=distance_passager,
                prix_passager=prix_passager,
            )

            # Créer automatiquement la conversation passager ↔ conducteur
            conv_id = None
            try:
                from apps.messagerie.models import Conversation, Participant
                conv = Conversation.objects.create(reservation=reservation)
                Participant.objects.create(conversation=conv, utilisateur=request.user)
                Participant.objects.create(conversation=conv, utilisateur=trajet.conducteur)
                conv_id = conv.id
            except Exception as exc:
                logger.warning("Erreur création conversation: %s", exc)

            prix_prevu = float(prix_passager or trajet.prix_par_place or 0)

            return Response({
                "message": "Réservation envoyée. En attente de confirmation.",
                "reservation_id": reservation.id,
                "conversation_id": conv_id,
                "code_embarquement": reservation.code_embarquement,
                "prix_prevu": str(prix_prevu),
            }, status=201)

    @action(detail=False, methods=['get'])
    def mes_reservations(self, request):
        """Toutes les réservations du passager (tous statuts) — utilisé par le dashboard et la page réservations."""
        reservations = Reservation.objects.filter(
            passager=request.user,
        ).select_related(
            'trajet', 'trajet__conducteur', 'passager', 'paiement'
        ).order_by('-date_reservation')[:100]
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=False, methods=['get'])
    def recues(self, request):
        """Toutes les réservations reçues par le conducteur (tous statuts) — utilisé par le dashboard."""
        reservations = Reservation.objects.filter(
            trajet__conducteur=request.user,
        ).select_related(
            'trajet', 'passager', 'paiement'
        ).order_by('-date_reservation')[:100]
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=False, methods=['get'], url_path='conducteur-historique')
    def conducteur_historique(self, request):
        """Historique des réservations terminées/annulées du conducteur, filtrable."""
        qs = Reservation.objects.filter(
            trajet__conducteur=request.user,
            statut__in=['terminee', 'declinee', 'annulee'],
        ).select_related('trajet', 'trajet__conducteur', 'passager', 'paiement')

        statut_param = request.query_params.get('statut', '').strip()
        if statut_param and statut_param != 'tous':
            qs = qs.filter(statut=statut_param)

        date_debut = request.query_params.get('date_debut', '').strip()
        date_fin = request.query_params.get('date_fin', '').strip()
        if date_debut:
            try:
                qs = qs.filter(date_reservation__date__gte=date_debut)
            except ValueError:
                pass
        if date_fin:
            try:
                qs = qs.filter(date_reservation__date__lte=date_fin)
            except ValueError:
                pass

        q = request.query_params.get('q', '').strip()
        if q:
            qs = qs.filter(
                Q(trajet__depart__icontains=q) |
                Q(trajet__destination__icontains=q) |
                Q(passager__first_name__icontains=q) |
                Q(passager__last_name__icontains=q) |
                Q(passager__username__icontains=q) |
                Q(id__icontains=q)
            )

        qs = qs.order_by('-date_reservation')[:100]
        return Response(ReservationSerializer(qs, many=True).data)

    @action(detail=True, methods=['post'])
    def confirmer(self, request, pk=None):
        with transaction.atomic():
            try:
                reservation = Reservation.objects.select_related('trajet').get(
                    pk=pk, trajet__conducteur=request.user
                )
            except Reservation.DoesNotExist:
                raise PermissionDenied("Réservation introuvable ou accès non autorisé.")

            if reservation.statut == 'confirmee':
                return Response({"error": "Déjà confirmée."}, status=400)

            # Verrouiller le trajet pour sérialiser les confirmations concurrentes.
            # Sans ce verrou, deux clics simultanés du conducteur peuvent confirmer
            # plus de passagers que le nombre de places disponibles.
            trajet = Trajet.objects.select_for_update().get(pk=reservation.trajet_id)

            nb_confirmees = trajet.reservations.filter(statut='confirmee').count()
            if nb_confirmees >= trajet.places_disponibles:
                return Response(
                    {"error": f"Capacité atteinte : {trajet.places_disponibles} place(s) maximum."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            reservation.statut = 'confirmee'
            reservation.save()

        prix_par_place = float(trajet.prix_par_place) if trajet.prix_par_place is not None else 0.0

        return Response({
            "message": "Réservation confirmée.",
            "prix_par_place": prix_par_place,
            "nb_passagers_confirmes": nb_confirmees + 1,
        })

    @action(detail=True, methods=['post'])
    def decliner(self, request, pk=None):
        # CORRECTION IDOR : Filtrage direct par conducteur
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk, trajet__conducteur=request.user)
        except Reservation.DoesNotExist:
            raise PermissionDenied("Réservation introuvable ou accès non autorisé.")

        if reservation.statut == 'declinee':
            return Response({"error": "Déjà déclinée."}, status=400)

        reservation.statut = 'declinee'
        reservation.save()

        # Conversation en lecture seule — le passager peut encore lire mais pas écrire
        try:
            from apps.messagerie.models import Conversation
            Conversation.objects.filter(reservation=reservation).update(
                statut=Conversation.LECTURE_SEULE
            )
        except Exception:
            pass

        return Response({"message": "Réservation déclinée."})
    
    @action(detail=True, methods=['post'])
    def annuler(self, request, pk=None):
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk, passager=request.user)
        except Reservation.DoesNotExist:
            raise PermissionDenied("Réservation introuvable ou accès non autorisé.")

        if reservation.statut not in ('en_attente', 'confirmee'):
            return Response(
                {"error": "Cette réservation ne peut plus être annulée."},
                status=400,
            )

        penalite = 0
        message = "Réservation annulée avec succès."

        # Pénalité si annulation < 2h avant le départ
        depart = reservation.trajet.date_heure_depart
        if depart and timezone.now() >= depart - timedelta(hours=2):
            prix = float(reservation.prix_passager or reservation.trajet.prix_par_place or 0)
            penalite = math.ceil(prix * PENALITE_ANNULATION_TARDIVE / 25) * 25
            message = f"Réservation annulée avec une pénalité de {penalite} FCFA (annulation tardive)."

        Reservation.objects.filter(pk=reservation.pk).update(
            statut='annulee',
            penalite_annulation=penalite,
        )

        return Response({"message": message, "penalite_fcfa": penalite})
    
    @action(detail=False, methods=['get'])
    def historique(self, request):
        """Historique des réservations terminées/annulées/refusées, filtrable."""
        qs = Reservation.objects.filter(
            passager=request.user,
            statut__in=['terminee', 'declinee', 'annulee'],
        ).select_related('trajet', 'trajet__conducteur', 'passager', 'paiement')

        statut_param = request.query_params.get('statut', '').strip()
        if statut_param and statut_param != 'tous':
            qs = qs.filter(statut=statut_param)

        date_debut = request.query_params.get('date_debut', '').strip()
        date_fin = request.query_params.get('date_fin', '').strip()
        if date_debut:
            try:
                qs = qs.filter(date_reservation__date__gte=date_debut)
            except ValueError:
                pass
        if date_fin:
            try:
                qs = qs.filter(date_reservation__date__lte=date_fin)
            except ValueError:
                pass

        q = request.query_params.get('q', '').strip()
        if q:
            qs = qs.filter(
                Q(trajet__depart__icontains=q) |
                Q(trajet__destination__icontains=q) |
                Q(trajet__conducteur__first_name__icontains=q) |
                Q(trajet__conducteur__last_name__icontains=q) |
                Q(trajet__conducteur__username__icontains=q) |
                Q(id__icontains=q)
            )

        qs = qs.order_by('-date_reservation')[:100]
        serializer = ReservationSerializer(qs, many=True)
        return Response(serializer.data)

    # ── QR Code de montée ─────────────────────────────────────────────────
    @action(detail=True, methods=['get'], url_path='qr-code')
    def qr_code(self, request, pk=None):
        """
        Génère un token HMAC signé pour la réservation.
        Le passager présente ce code au conducteur au moment de la montée.
        Valide pendant 2 heures (tolérance de 1h de chaque côté).
        """
        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'trajet__conducteur'
            ).get(pk=pk, passager=request.user, statut='confirmee')
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable ou non confirmée.")

        # Token valide par tranche horaire (change toutes les heures)
        ts_heure = str(int(time.time()) // 3600)
        secret   = settings.SECRET_KEY.encode()
        token    = hmac_lib.new(
            secret,
            f"{pk}:{ts_heure}".encode(),
            hashlib.sha256,
        ).hexdigest()[:24].upper()

        return Response({
            "token":          token,
            "reservation_id": str(pk),
            "passager":       request.user.get_full_name() or request.user.username,
            "trajet":         f"{reservation.trajet.depart} → {reservation.trajet.destination}",
            "date_depart":    reservation.trajet.date_heure_depart.isoformat(),
            "places":         reservation.places_reservees,
            "expire_dans":    "1 heure",
        })

    # ── Scanner le QR Code (conducteur) ──────────────────────────────────
    @action(detail=True, methods=['post'], url_path='scanner-qr')
    def scanner_qr(self, request, pk=None):
        """
        Conducteur saisit le code affiché par le passager → validation de la montée.
        Body: { token }
        """
        token_recu = str(request.data.get('token', '')).strip().upper()
        if not token_recu:
            return Response({"error": "Token manquant."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=pk, trajet__conducteur=request.user, statut='confirmee')
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable ou vous n'êtes pas le conducteur.")

        # Vérifier sur l'heure courante ET l'heure précédente (tolérance)
        secret = settings.SECRET_KEY.encode()
        ts_now = int(time.time()) // 3600

        valide = any(
            hmac_lib.compare_digest(
                hmac_lib.new(
                    secret,
                    f"{pk}:{ts}".encode(),
                    hashlib.sha256,
                ).hexdigest()[:24].upper(),
                token_recu,
            )
            for ts in [ts_now, ts_now - 1]
        )

        if not valide:
            return Response(
                {"error": "Code invalide ou expiré. Demandez au passager d'actualiser son code."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response({
            "valide":   True,
            "passager": reservation.passager.get_full_name() or reservation.passager.username,
            "places":   reservation.places_reservees,
            "trajet":   f"{reservation.trajet.depart} → {reservation.trajet.destination}",
        })

    # ── Code PIN embarquement (passager) ─────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='code-embarquement')
    def code_embarquement(self, request, pk=None):
        """
        Passager récupère son code PIN KVT-XXXX à présenter au conducteur.
        Disponible uniquement sur une réservation confirmée.
        """
        try:
            reservation = Reservation.objects.select_related('trajet').get(
                pk=pk, passager=request.user, statut='confirmee'
            )
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable ou non confirmée.")

        return Response({
            "code_embarquement": reservation.code_embarquement,
            "trajet": f"{reservation.trajet.depart} → {reservation.trajet.destination}",
            "date_depart": reservation.trajet.date_heure_depart,
            "statut_embarquement": reservation.statut_embarquement,
            "prix_passager": reservation.prix_passager or reservation.trajet.prix_par_place,
        })

    # ── Embarquement passager (conducteur valide le code PIN) ─────────────────

    @action(detail=False, methods=['post'], url_path='embarquer')
    def embarquer(self, request):
        """
        Conducteur saisit le code KVT-XXXX du passager → valide la montée.
        Body: { code_embarquement: "KVT-1234" }
        """
        code = str(request.data.get('code_embarquement', '')).strip().upper()
        if not code:
            return Response({"error": "code_embarquement requis."}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(
                code_embarquement=code,
                trajet__conducteur=request.user,
                statut='confirmee',
            )
        except Reservation.DoesNotExist:
            return Response({"error": "Code invalide ou réservation introuvable."}, status=404)

        if reservation.statut_embarquement == 'embarque':
            return Response({"error": "Ce passager est déjà enregistré comme embarqué."}, status=400)

        reservation.statut_embarquement = 'embarque'
        reservation.heure_embarquement = timezone.now()
        reservation.save(update_fields=['statut_embarquement', 'heure_embarquement'])

        return Response({
            "message": "Embarquement validé.",
            "passager": reservation.passager.get_full_name() or reservation.passager.username,
            "heure_embarquement": reservation.heure_embarquement,
            "trajet": f"{reservation.trajet.depart} → {reservation.trajet.destination}",
        })

    # ── Débarquement passager (conducteur confirme la dépose) ─────────────────

    @action(detail=True, methods=['post'], url_path='debarquer')
    def debarquer(self, request, pk=None):
        """
        Conducteur confirme que le passager a été déposé.
        """
        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=pk, trajet__conducteur=request.user)
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable.")

        if reservation.statut_embarquement != 'embarque':
            return Response({"error": "Le passager n'est pas encore enregistré comme embarqué."}, status=400)

        reservation.statut_embarquement = 'depose'
        reservation.heure_depose = timezone.now()
        reservation.save(update_fields=['statut_embarquement', 'heure_depose'])

        return Response({
            "message": "Dépose confirmée.",
            "passager": reservation.passager.get_full_name() or reservation.passager.username,
            "heure_depose": reservation.heure_depose,
        })