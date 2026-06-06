from django.db import transaction
from django.utils import timezone
import uuid
import logging
import requests

logger = logging.getLogger(__name__)
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from ..modeles.models import Paiement, Reservation, Trajet

PAYGATE_API_KEY = getattr(settings, 'PAYGATE_API_KEY', '257081c0-e0ce-4aa4-9155-bd65856a6dce')
PAYGATE_URL_PAY    = "https://paygateglobal.com/api/v1/pay"
PAYGATE_URL_STATUS = "https://paygateglobal.com/api/v2/status"

COMMISSION_KOVOIT = 0.10  # 10%

class PaiementViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    # ── Initier un paiement mobile ────────────────────────────────────────
    @action(detail=False, methods=['post'])
    def initier(self, request):
        """
        Initie un paiement mobile via PayGate.
        Body: { reservation_id, phone_number, network (FLOOZ | TMONEY) }
        """
        reservation_id = request.data.get('reservation_id')
        phone_number   = request.data.get('phone_number')
        network        = request.data.get('network', '').upper()

        # Validations
        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)
        if not phone_number:
            return Response({"error": "phone_number requis."}, status=400)
        if network not in ['FLOOZ', 'TMONEY']:
            return Response({"error": "network doit être FLOOZ ou TMONEY."}, status=400)

        # Vérifier la réservation
        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=reservation_id, passager=request.user)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        if reservation.statut != 'confirmee':
            return Response(
                {"error": "La réservation doit être confirmée avant le paiement."},
                status=400
            )

        # Vérifier qu'un paiement n'existe pas déjà (avec transaction atomique)
        with transaction.atomic():
            # select_for_update pour éviter les race conditions
            try:
                paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                if paiement.statut in [Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE]:
                    return Response({"error": "Cette réservation est déjà payée."}, status=400)
            except Paiement.DoesNotExist:
                paiement = None

            trajet  = reservation.trajet
            montant = int(trajet.prix_par_place)

            # Calcul commission KoVoit
            commission = round(montant * COMMISSION_KOVOIT)
            montant_conducteur = montant - commission

            # Identifiant unique pour cette transaction
            identifier = f"KOVOIT-{reservation_id}-{uuid.uuid4().hex[:8].upper()}"

            # Appel PayGate
            try:
                response = requests.post(PAYGATE_URL_PAY, json={
                    "auth_token":   PAYGATE_API_KEY,
                    "phone_number": phone_number,
                    "amount":       montant,
                    "description":  f"KoVoit - {trajet.depart} → {trajet.destination}",
                    "identifier":   identifier,
                    "network":      network,
                }, timeout=30)

                logger.debug("PayGate status: %s", response.status_code)
                data = response.json()
                logger.debug("PayGate response: %s", data)

            except requests.exceptions.Timeout:
                return Response({"error": "Timeout PayGate. Réessayez."}, status=503)
            except Exception as e:
                logger.error("PayGate error: %s", str(e))
                return Response({"error": f"Erreur PayGate: {str(e)}"}, status=503)

            # Traiter la réponse PayGate
            pg_status = data.get('status')

            if pg_status == 2:
                return Response({"error": "Clé API PayGate invalide."}, status=500)
            if pg_status == 4:
                return Response({"error": "Paramètres invalides pour PayGate."}, status=400)
            if pg_status == 6:
                return Response({"error": "Transaction en doublon. Réessayez."}, status=400)

            if pg_status != 0:
                return Response(
                    {"error": f"Erreur PayGate inattendue (status={pg_status})."},
                    status=500
                )

            tx_reference = data.get('tx_reference')

            # Créer ou mettre à jour le paiement en base (atomiquement)
            if paiement:
                paiement.montant        = montant
                paiement.moyen_paiement = network
                paiement.statut         = Paiement.Statut.EN_ATTENTE
                paiement.reference_mobile = tx_reference
                paiement.save()
            else:
                paiement = Paiement.objects.create(
                    reservation=reservation,
                    passager=request.user,
                    conducteur=trajet.conducteur,
                    montant=montant,
                    moyen_paiement=network,
                    statut=Paiement.Statut.EN_ATTENTE,
                    reference_mobile=tx_reference
                )

        return Response({
            "message":              "Paiement initié. Confirmez sur votre téléphone.",
            "tx_reference":         tx_reference,
            "identifier":           identifier,
            "montant":              montant,
            "commission_kovoit":    commission,
            "montant_conducteur":   montant_conducteur,
            "network":              network,
            "phone_number":         phone_number,
        }, status=201)

    # ── Vérifier le statut d'un paiement ─────────────────────────────────
    @action(detail=False, methods=['post'])
    def verifier(self, request):
        """
        Vérifie le statut d'un paiement via PayGate.
        Body: { identifier }
        """
        identifier = request.data.get('identifier')
        if not identifier:
            return Response({"error": "identifier requis."}, status=400)

        try:
            response = requests.post(PAYGATE_URL_STATUS, json={
                "auth_token": PAYGATE_API_KEY,
                "identifier": identifier,
            }, timeout=30)
            data = response.json()
        except Exception as e:
            return Response({"error": f"Erreur PayGate: {str(e)}"}, status=503)

        pg_status = data.get('status')

        # Mapper le statut PayGate vers notre modèle
        if pg_status == 0:
            statut_label = "payee"
            message      = "Paiement réussi."
        elif pg_status == 2:
            statut_label = "en_attente"
            message      = "Paiement en cours de traitement."
        elif pg_status == 4:
            statut_label = "echouee"
            message      = "Paiement expiré."
        elif pg_status == 6:
            statut_label = "echouee"
            message      = "Paiement annulé."
        else:
            statut_label = "en_attente"
            message      = "Statut inconnu."

        # Si paiement réussi, mettre à jour en base (atomiquement)
        if pg_status == 0:
            try:
                with transaction.atomic():
                    # Format: KOVOIT-{reservation_id}-{hash}
                    parts          = identifier.split('-')
                    reservation_id = parts[1]
                    
                    # Utiliser select_for_update pour éviter les race conditions
                    reservation = Reservation.objects.select_for_update().get(pk=reservation_id)
                    try:
                        paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                        paiement.statut = Paiement.Statut.PAYEE
                        paiement.date_payement = timezone.now()
                        paiement.save()
                        logger.info(f"Paiement confirmé pour réservation {reservation_id}")
                    except Paiement.DoesNotExist:
                        logger.warning(f"Paiement introuvable pour réservation {reservation_id}")
            except Reservation.DoesNotExist:
                logger.warning(f"Réservation {reservation_id} introuvable")
            except Exception as e:
                logger.error(f"Erreur lors de la mise à jour du paiement: {str(e)}")

        return Response({
            "statut":            statut_label,
            "message":           message,
            "pg_status":         pg_status,
            "tx_reference":      data.get('tx_reference'),
            "payment_reference": data.get('payment_reference'),
            "payment_method":    data.get('payment_method'),
            "datetime":          data.get('datetime'),
        })

    # ── Initier un paiement en espèces ────────────────────────────────────────
    @action(detail=False, methods=['post'])
    def initier_especes(self, request):
        """
        Le passager initie un paiement en espèces.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=reservation_id, passager=request.user)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        if reservation.statut != 'confirmee':
            return Response(
                {"error": "La réservation doit être confirmée avant le paiement."},
                status=400
            )

        # Utiliser transaction.atomic() pour éviter les doublons
        with transaction.atomic():
            # Vérifier qu'aucun paiement n'existe déjà
            try:
                paiement_existant = reservation.paiement
                if paiement_existant.statut in [Paiement.Statut.CONFIRME, Paiement.Statut.EN_ATTENTE_CONFIRMATION]:
                    return Response({"error": "Un paiement existe déjà pour cette réservation."}, status=400)
                # Si le paiement est annulé ou échoué, on peut en créer un nouveau
                paiement_existant.delete()
            except Paiement.DoesNotExist:
                pass

            trajet = reservation.trajet
            montant = trajet.prix_par_place
            commission = round(float(montant) * COMMISSION_KOVOIT)

            # Créer le paiement en espèces
            paiement = Paiement.objects.create(
                reservation=reservation,
                passager=request.user,
                conducteur=trajet.conducteur,
                montant=montant,
                moyen_paiement='ESPECE',
                statut=Paiement.Statut.EN_ATTENTE_CONFIRMATION
            )

        return Response({
            "message": "Paiement en espèces initié. En attente de confirmation du conducteur.",
            "paiement_id": paiement.id,
            "montant": float(montant),
            "commission_kovoit": commission,
            "montant_conducteur": float(montant) - commission,
            "statut": paiement.statut,
        }, status=201)

    # ──── Confirmer paiement en espèces (conducteur) ────────────────────────────
    @action(detail=False, methods=['post'])
    def confirmer_especes(self, request):
        """
        Le conducteur confirme la réception du paiement en espèces.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)

        try:
            # Utiliser transaction atomique + select_for_update pour éviter les race conditions
            with transaction.atomic():
                reservation = Reservation.objects.select_for_update().select_related(
                    'trajet', 'trajet__conducteur', 'passager'
                ).get(
                    pk=reservation_id,
                    trajet__conducteur=request.user
                )
        except Reservation.DoesNotExist:
            return Response(
                {"error": "Réservation introuvable ou vous n'êtes pas le conducteur."}, 
                status=404
            )

        # Vérifier qu'un paiement en attente existe
        try:
            paiement = Paiement.objects.select_for_update().get(reservation=reservation)
        except Paiement.DoesNotExist:
            return Response({"error": "Aucun paiement pour cette réservation."}, status=404)

        if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
            return Response({
                "error": f"Ce paiement n'est pas en attente (statut: {paiement.statut})."
            }, status=400)

        if paiement.moyen_paiement != 'ESPECE':
            return Response({
                "error": f"Ce n'est pas un paiement en espèces (moyen: {paiement.moyen_paiement})."
            }, status=400)

        # ──── Transaction atomique : confirmer paiement ────
        try:
            with transaction.atomic():
                # Double-vérifier le statut après le lock
                paiement.refresh_from_db()
                if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
                    return Response({
                        "error": "Le paiement a déjà été traité par quelqu'un d'autre."
                    }, status=400)

                # Confirmer le paiement
                paiement.statut = Paiement.Statut.CONFIRME
                paiement.date_confirmation = timezone.now()
                paiement.save()
                
                logger.info(f"Paiement {paiement.id} confirmé en espèces par {request.user.username}")

                # Mettre à jour la réservation si nécessaire
                if reservation.statut == 'en_attente':
                    reservation.statut = 'confirmee'
                    reservation.save()

        except Exception as e:
            logger.error(f"Erreur lors de la confirmation du paiement: {str(e)}")
            return Response({
                "error": f"Erreur lors de la confirmation: {str(e)}"
            }, status=500)

        # Calculer les statistiques
        montant = float(paiement.montant)
        commission = round(montant * COMMISSION_KOVOIT)
        montant_conducteur = montant - commission

        return Response({
            "message": "Paiement en espèces confirmé avec succès ✓",
            "paiement_id": paiement.id,
            "reservation_id": reservation.id,
            "montant": montant,
            "commission_kovoit": commission,
            "montant_conducteur": montant_conducteur,
            "date_confirmation": paiement.date_confirmation.isoformat(),
            "statut": paiement.statut,
        }, status=200)

    # ── Obtenir le statut de paiement d'une réservation ────────────────────────
    @action(detail=False, methods=['get'])
    def statut_reservation(self, request):
        """
        Retourne le statut de paiement pour une réservation donnée.
        Query: ?reservation_id=X
        """
        reservation_id = request.query_params.get('reservation_id')
        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager', 'trajet__conducteur'
            ).get(pk=reservation_id)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        # Vérifier les permissions : passager ou conducteur du trajet
        if not (request.user == reservation.passager or request.user == reservation.trajet.conducteur):
            return Response({"error": "Accès non autorisé."}, status=403)

        try:
            paiement = reservation.paiement
            data = {
                "paiement_id": paiement.id,
                "statut": paiement.statut,
                "moyen_paiement": paiement.moyen_paiement,
                "montant": float(paiement.montant),
                "date_creation": paiement.date_creation,
                "date_confirmation": paiement.date_confirmation,
            }
        except Paiement.DoesNotExist:
            data = {"statut": "AUCUN", "message": "Aucun paiement initié"}

        return Response(data)

    # ── Mes paiements (passager) ──────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def mes_paiements(self, request):
        paiements = Paiement.objects.filter(
            reservation__passager=request.user
        ).select_related(
            'reservation', 'reservation__trajet'
        ).order_by('-reservation__date_reservation')

        data = [{
            "id":               p.id,
            "reservation_id":   p.reservation.id,
            "depart":           p.reservation.trajet.depart,
            "destination":      p.reservation.trajet.destination,
            "date_trajet":      p.reservation.trajet.date_heure_depart,
            "montant":          float(p.montant),
            "commission":       round(float(p.montant) * COMMISSION_KOVOIT),
            "moyen_paiement":   p.moyen_paiement,
            "statut":           p.statut,
            "date_paiement":    p.date_payement,
        } for p in paiements]

        return Response(data)

    # ── Soumettre référence T-Money / Flooz (manuel) ─────────────────────
    @action(detail=False, methods=['post'])
    def soumettre_reference_mobile(self, request):
        """
        Le passager soumet sa référence USSD après avoir effectué
        le virement T-Money ou Flooz sur son téléphone.
        Body: { reservation_id, reference_mobile, network (TMONEY|FLOOZ) }
        """
        reservation_id   = request.data.get('reservation_id')
        reference_mobile = request.data.get('reference_mobile', '').strip()
        network          = request.data.get('network', '').upper()

        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)
        if not reference_mobile:
            return Response({"error": "La référence de paiement est requise."}, status=400)
        if network not in ['FLOOZ', 'TMONEY']:
            return Response({"error": "network doit être FLOOZ ou TMONEY."}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=reservation_id, passager=request.user)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        if reservation.statut != 'confirmee':
            return Response(
                {"error": "La réservation doit être confirmée avant le paiement."},
                status=400
            )

        with transaction.atomic():
            try:
                paiement_existant = reservation.paiement
                if paiement_existant.statut == Paiement.Statut.CONFIRME:
                    return Response({"error": "Ce paiement est déjà confirmé."}, status=400)
                paiement_existant.delete()
            except Paiement.DoesNotExist:
                pass

            trajet  = reservation.trajet
            montant = trajet.prix_par_place

            paiement = Paiement.objects.create(
                reservation=reservation,
                passager=request.user,
                conducteur=trajet.conducteur,
                montant=montant,
                moyen_paiement=network,
                reference_mobile=reference_mobile,
                statut=Paiement.Statut.EN_ATTENTE_CONFIRMATION,
            )

        commission = round(float(montant) * COMMISSION_KOVOIT)
        return Response({
            "message": "Référence soumise. Le conducteur doit confirmer la réception.",
            "paiement_id": paiement.id,
            "reference_mobile": reference_mobile,
            "montant": float(montant),
            "commission_kovoit": commission,
            "statut": paiement.statut,
        }, status=201)

    # ── Confirmer paiement mobile money (conducteur) ──────────────────────
    @action(detail=False, methods=['post'])
    def confirmer_mobile(self, request):
        """
        Le conducteur confirme qu'il a reçu le virement T-Money / Flooz.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({"error": "reservation_id requis."}, status=400)

        try:
            reservation = Reservation.objects.select_related('trajet').get(
                pk=reservation_id, trajet__conducteur=request.user
            )
        except Reservation.DoesNotExist:
            return Response(
                {"error": "Réservation introuvable ou vous n'êtes pas le conducteur."},
                status=404
            )

        try:
            paiement = reservation.paiement
        except Paiement.DoesNotExist:
            return Response({"error": "Aucun paiement en attente pour cette réservation."}, status=404)

        if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
            return Response({"error": "Ce paiement n'est pas en attente de confirmation."}, status=400)

        if paiement.moyen_paiement not in ['FLOOZ', 'TMONEY']:
            return Response({"error": "Utilisez confirmer_especes pour un paiement en espèces."}, status=400)

        with transaction.atomic():
            paiement.refresh_from_db()
            if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
                return Response({"error": "Le paiement a déjà été traité."}, status=400)
            paiement.statut = Paiement.Statut.CONFIRME
            paiement.date_confirmation = timezone.now()
            paiement.save()

        montant    = float(paiement.montant)
        commission = round(montant * COMMISSION_KOVOIT)
        return Response({
            "message": "Paiement mobile money confirmé avec succès.",
            "paiement_id": paiement.id,
            "montant": montant,
            "commission_kovoit": commission,
            "montant_conducteur": montant - commission,
            "reference_mobile": paiement.reference_mobile,
            "date_confirmation": paiement.date_confirmation,
        })

    # ── Webhook PayGate (confirmation automatique) ────────────────────────
    @action(detail=False, methods=['post'], permission_classes=[])
    def webhook(self, request):
        """
        PayGate envoie une confirmation POST après paiement réussi.
        """
        identifier       = request.data.get('identifier')
        tx_reference     = request.data.get('tx_reference')
        payment_method   = request.data.get('payment_method')
        montant          = request.data.get('amount')

        if not identifier:
            return Response(status=400)

        try:
            parts          = identifier.split('-')
            reservation_id = parts[1]
            reservation    = Reservation.objects.get(pk=reservation_id)

            paiement, _ = Paiement.objects.get_or_create(
                reservation=reservation,
                defaults={
                    'montant':        montant or reservation.trajet.prix_par_place,
                    'moyen_paiement': payment_method or 'mobile',
                    'statut':         'payee',
                }
            )
            paiement.statut = 'payee'
            paiement.save()

        except Exception:
            pass

        return Response({"status": "ok"})