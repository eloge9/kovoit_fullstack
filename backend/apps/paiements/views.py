from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from decimal import Decimal, InvalidOperation
import hashlib
import hmac
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
            montant = int(reservation.places_reservees * trajet.prix_par_place)

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

                    # Vérification d'appartenance : seul le passager ayant initié peut déclencher la MAJ
                    reservation = Reservation.objects.select_for_update().get(
                        pk=reservation_id,
                        passager=request.user,
                    )
                    try:
                        paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                        paiement.statut = Paiement.Statut.PAYEE
                        paiement.date_payement = timezone.now()
                        paiement.save()
                        logger.info("Paiement confirmé pour réservation %s", reservation_id)
                    except Paiement.DoesNotExist:
                        logger.warning("Paiement introuvable pour réservation %s", reservation_id)
            except Reservation.DoesNotExist:
                logger.warning("Réservation %s introuvable ou non autorisée", reservation_id)
            except (IndexError, ValueError):
                logger.warning("Identifier PayGate malformé : %s", identifier)
            except Exception as e:
                logger.error("Erreur lors de la mise à jour du paiement: %s", str(e))

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

        with transaction.atomic():
            try:
                paiement_existant = Paiement.objects.select_for_update().get(reservation=reservation)
                if paiement_existant.statut in [Paiement.Statut.CONFIRME, Paiement.Statut.EN_ATTENTE_CONFIRMATION]:
                    return Response({"error": "Un paiement existe déjà pour cette réservation."}, status=400)
                paiement_existant.delete()
            except Paiement.DoesNotExist:
                pass

            trajet = reservation.trajet
            # Montant total = places réservées × prix par place
            montant = reservation.places_reservees * trajet.prix_par_place
            commission = round(float(montant) * COMMISSION_KOVOIT)

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
            with transaction.atomic():
                try:
                    reservation = Reservation.objects.select_for_update().select_related(
                        'trajet', 'trajet__conducteur', 'passager'
                    ).get(pk=reservation_id, trajet__conducteur=request.user)
                except Reservation.DoesNotExist:
                    return Response(
                        {"error": "Réservation introuvable ou vous n'êtes pas le conducteur."},
                        status=404
                    )

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

                paiement.statut = Paiement.Statut.CONFIRME
                paiement.date_confirmation = timezone.now()
                paiement.save()

                logger.info("Paiement %s confirmé en espèces par %s", paiement.id, request.user.username)

        except Exception as e:
            logger.error("Erreur lors de la confirmation du paiement: %s", str(e))
            return Response({"error": f"Erreur lors de la confirmation: {str(e)}"}, status=500)

        montant = float(paiement.montant)
        commission = round(montant * COMMISSION_KOVOIT)

        return Response({
            "message": "Paiement en espèces confirmé avec succès.",
            "paiement_id": paiement.id,
            "reservation_id": reservation.id,
            "montant": montant,
            "commission_kovoit": commission,
            "montant_conducteur": montant - commission,
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

        # Filtre propriétaire dans la même requête : évite le timing-leak IDOR
        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager', 'trajet__conducteur'
            ).get(
                Q(passager=request.user) | Q(trajet__conducteur=request.user),
                pk=reservation_id,
            )
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

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

    # ── Paiements reçus par le conducteur ────────────────────────────────
    @action(detail=False, methods=['get'])
    def paiements_conducteur(self, request):
        """
        Retourne l'historique des paiements reçus par le conducteur.
        Paramètres optionnels: date_debut, date_fin (YYYY-MM-DD), mois, annee
        """
        qs = Paiement.objects.filter(
            conducteur=request.user,
            statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
        ).select_related(
            'reservation', 'reservation__trajet', 'reservation__passager'
        ).order_by('-date_creation')

        # Filtres optionnels
        date_debut = request.query_params.get('date_debut')
        date_fin   = request.query_params.get('date_fin')
        mois       = request.query_params.get('mois')
        annee      = request.query_params.get('annee')

        from datetime import datetime as dt

        if date_debut and date_fin:
            try:
                d1 = dt.strptime(date_debut, '%Y-%m-%d').date()
                d2 = dt.strptime(date_fin,   '%Y-%m-%d').date()
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__date__gte=d1, date_confirmation__date__lte=d2) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__date__gte=d1,     date_payement__date__lte=d2)
                )
            except ValueError:
                return Response({"error": "Format date invalide (YYYY-MM-DD)."}, status=400)
        elif mois and annee:
            try:
                m, a = int(mois), int(annee)
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__year=a, date_confirmation__month=m) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__year=a,     date_payement__month=m)
                )
            except ValueError:
                return Response({"error": "mois/annee invalides."}, status=400)
        elif annee:
            try:
                a = int(annee)
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__year=a) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__year=a)
                )
            except ValueError:
                return Response({"error": "annee invalide."}, status=400)

        data = []
        for p in qs:
            montant    = float(p.montant)
            commission = round(montant * COMMISSION_KOVOIT)
            net        = montant - commission
            resa       = p.reservation
            trajet     = resa.trajet
            passager   = resa.passager

            # Date effective du paiement
            date_effective = p.date_payement or p.date_confirmation or p.date_creation

            data.append({
                "paiement_id":      p.id,
                "reservation_id":   resa.id,
                "depart":           trajet.depart,
                "destination":      trajet.destination,
                "date_trajet":      trajet.date_heure_depart.strftime('%Y-%m-%d') if trajet.date_heure_depart else None,
                "date_paiement":    date_effective.strftime('%Y-%m-%d') if date_effective else None,
                "passager_nom":     f"{passager.first_name} {passager.last_name}".strip() or passager.username,
                "places":           resa.places_reservees,
                "montant_brut":     montant,
                "commission_kovoit": commission,
                "montant_net":      net,
                "taux_commission":  COMMISSION_KOVOIT,
                "moyen_paiement":   p.moyen_paiement,
                "statut":           p.statut,
            })

        # Totaux globaux pour la période
        total_brut       = sum(d["montant_brut"]      for d in data)
        total_commission = sum(d["commission_kovoit"]  for d in data)
        total_net        = sum(d["montant_net"]        for d in data)

        return Response({
            "nombre":            len(data),
            "total_brut":        round(total_brut),
            "total_commission":  round(total_commission),
            "total_net":         round(total_net),
            "taux_commission":   COMMISSION_KOVOIT,
            "paiements":         data,
        })

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
                paiement_existant = Paiement.objects.select_for_update().get(reservation=reservation)
                if paiement_existant.statut == Paiement.Statut.CONFIRME:
                    return Response({"error": "Ce paiement est déjà confirmé."}, status=400)
                paiement_existant.delete()
            except Paiement.DoesNotExist:
                pass

            trajet  = reservation.trajet
            montant = reservation.places_reservees * trajet.prix_par_place

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
            with transaction.atomic():
                try:
                    reservation_locked = Reservation.objects.select_for_update().select_related(
                        'trajet'
                    ).get(pk=reservation_id, trajet__conducteur=request.user)
                except Reservation.DoesNotExist:
                    return Response(
                        {"error": "Réservation introuvable ou vous n'êtes pas le conducteur."},
                        status=404
                    )

                try:
                    paiement = Paiement.objects.select_for_update().get(reservation=reservation_locked)
                except Paiement.DoesNotExist:
                    return Response({"error": "Aucun paiement en attente pour cette réservation."}, status=404)

                if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
                    return Response({"error": "Ce paiement n'est pas en attente de confirmation."}, status=400)

                if paiement.moyen_paiement not in ['FLOOZ', 'TMONEY']:
                    return Response({"error": "Utilisez confirmer_especes pour un paiement en espèces."}, status=400)

                paiement.statut = Paiement.Statut.CONFIRME
                paiement.date_confirmation = timezone.now()
                paiement.save()

        except Exception as e:
            logger.error("Erreur lors de la confirmation mobile: %s", str(e))
            return Response({"error": f"Erreur lors de la confirmation: {str(e)}"}, status=500)

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
        Endpoint appelé par PayGate après paiement réussi.

        Sécurité :
          - Vérifie auth_token par comparaison temporellement constante (anti timing-attack).
          - Vérifie la signature HMAC-SHA256 si l'en-tête X-PayGate-Signature est présent.
          - Retourne 500 si une erreur inattendue survient (force PayGate à re-tenter).
          - Idempotent : un paiement déjà confirmé répond 200 sans re-traitement.
        """
        # ── 1. Résoudre le secret webhook ────────────────────────────────
        webhook_secret = (
            getattr(settings, 'PAYGATE_WEBHOOK_SECRET', None)
            or PAYGATE_API_KEY
        )
        if not webhook_secret:
            logger.critical("PAYGATE_WEBHOOK_SECRET non configuré — webhook refusé")
            return Response(status=500)

        # ── 2. Vérification auth_token (mécanisme natif PayGate) ─────────
        auth_token = request.data.get('auth_token', '')
        if not hmac.compare_digest(str(auth_token), str(webhook_secret)):
            logger.warning(
                "Webhook PayGate rejeté : auth_token invalide (IP=%s)",
                request.META.get('REMOTE_ADDR'),
            )
            return Response(status=403)

        # ── 3. Vérification HMAC-SHA256 optionnelle ──────────────────────
        # PayGate peut envoyer X-PayGate-Signature = HMAC-SHA256(secret, raw_body)
        hmac_header = request.headers.get('X-PayGate-Signature', '')
        if hmac_header:
            raw_body = request._request.body
            expected = hmac.new(
                webhook_secret.encode('utf-8'),
                raw_body,
                hashlib.sha256,
            ).hexdigest()
            if not hmac.compare_digest(hmac_header, expected):
                logger.warning("Webhook PayGate rejeté : signature HMAC invalide")
                return Response(status=403)

        # ── 4. Validation de l'identifier ────────────────────────────────
        identifier = request.data.get('identifier', '')
        if not identifier:
            return Response({"error": "identifier manquant"}, status=400)

        try:
            parts = identifier.split('-')
            # Format attendu : KOVOIT-{reservation_id}-{hash8}
            if len(parts) < 3 or parts[0] != 'KOVOIT' or not parts[1]:
                raise ValueError("format invalide")
            reservation_id = parts[1]
        except (ValueError, IndexError):
            logger.warning("Webhook PayGate : identifier malformé '%s'", identifier)
            return Response({"error": "identifier invalide"}, status=400)

        # ── 5. Mise à jour atomique sous verrou ───────────────────────────
        try:
            with transaction.atomic():
                try:
                    reservation = Reservation.objects.select_for_update().select_related(
                        'trajet'
                    ).get(pk=reservation_id)
                except Reservation.DoesNotExist:
                    logger.warning("Webhook PayGate : réservation %s introuvable", reservation_id)
                    # 200 = on ne déclenche pas les retries PayGate pour des IDs inconnus
                    return Response({"status": "ok"})

                try:
                    paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                except Paiement.DoesNotExist:
                    logger.warning(
                        "Webhook PayGate : aucun paiement initié pour réservation %s",
                        reservation_id,
                    )
                    return Response({"status": "ok"})

                # Idempotence : ne pas re-traiter un paiement déjà confirmé
                if paiement.statut in (Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE):
                    return Response({"status": "ok"})

                # Valider que le montant reçu correspond au montant attendu en DB
                montant_recu = request.data.get('amount')
                if montant_recu is not None:
                    try:
                        if Decimal(str(montant_recu)) != paiement.montant:
                            logger.error(
                                "Webhook PayGate : montant incohérent pour paiement %s "
                                "(reçu=%s, attendu=%s)",
                                paiement.id, montant_recu, paiement.montant,
                            )
                            return Response({"error": "montant incohérent"}, status=400)
                    except (InvalidOperation, TypeError):
                        pass  # Montant absent ou non parseable → on ne bloque pas

                paiement.statut = Paiement.Statut.PAYEE
                paiement.reference_mobile = (
                    request.data.get('tx_reference') or paiement.reference_mobile
                )
                paiement.date_payement = timezone.now()
                paiement.save()

                logger.info(
                    "Webhook PayGate : paiement %s confirmé pour réservation %s",
                    paiement.id, reservation_id,
                )

        except Exception as e:
            # 500 force PayGate à re-tenter la livraison du webhook
            logger.error("Webhook PayGate : erreur inattendue — %s", str(e))
            return Response(status=500)

        return Response({"status": "ok"})