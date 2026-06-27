"""
Module paiements — PayPlus Africa (Moov Flooz & Mixx by Yas).

Flux :
  1. Passager initie (FLOOZ ou YAS) → PayPlus push Mobile Money → webhook confirme → DB mise à jour.
  2. Passager choisit espèces → Conducteur confirme à la fin du trajet.

Sécurité :
  - Verrou select_for_update pour éviter les double-paiements.
  - Idempotence sur le webhook.
  - Validation montant serveur côté webhook.
  - Signature HMAC-SHA256 sur le webhook.
"""
import logging
import uuid
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..modeles.models import Notification, Paiement, Reservation
from . import payplus_service as payplus

logger = logging.getLogger(__name__)

COMMISSION_KOVOIT = 0.10  # 10 %

# URL de notification par défaut (override via settings.PAYPLUS_NOTIFY_URL)
_NOTIFY_URL = getattr(settings, 'PAYPLUS_NOTIFY_URL', 'https://kovoit.com/api/paiements/webhook/')


# ─────────────────────────────────────────────────────────────────────────────
def _notifier(utilisateur, contenu: str):
    """Crée une notification en base pour l'utilisateur."""
    try:
        Notification.objects.create(utilisateur=utilisateur, contenu=contenu)
    except Exception as exc:
        logger.warning('[Paiement] notification skipped: %s', exc)


def _calcul(paiement: Paiement) -> tuple[float, float, float]:
    montant    = float(paiement.montant)
    commission = round(montant * COMMISSION_KOVOIT)
    net        = montant - commission
    return montant, commission, net


# ─────────────────────────────────────────────────────────────────────────────
class PaiementViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    # ── 1. Initier paiement Mobile Money (Moov Flooz ou Mixx by Yas) ────────
    @action(detail=False, methods=['post'])
    def initier(self, request):
        """
        Initie un paiement Mobile Money via PayPlus Africa.
        Body: { reservation_id, phone_number, network ('FLOOZ' | 'YAS') }
        """
        reservation_id = request.data.get('reservation_id')
        phone_number   = request.data.get('phone_number', '').strip()
        network        = request.data.get('network', '').upper()

        if not reservation_id:
            return Response({'error': 'reservation_id requis.'}, status=400)
        if not phone_number:
            return Response({'error': 'phone_number requis.'}, status=400)
        if network not in ('FLOOZ', 'YAS'):
            return Response({'error': "network doit être 'FLOOZ' (Moov Flooz) ou 'YAS' (Mixx by Yas)."}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=reservation_id, passager=request.user)
        except Reservation.DoesNotExist:
            return Response({'error': 'Réservation introuvable.'}, status=404)

        if reservation.statut != 'confirmee':
            return Response({'error': 'La réservation doit être confirmée avant le paiement.'}, status=400)

        with transaction.atomic():
            try:
                paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                if paiement.statut in (Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE):
                    return Response({'error': 'Cette réservation est déjà payée.'}, status=400)
            except Paiement.DoesNotExist:
                paiement = None

            trajet        = reservation.trajet
            prix_unitaire = float(reservation.prix_passager or trajet.prix_par_place or 0)
            montant       = int(reservation.places_reservees * prix_unitaire)
            commission         = round(montant * COMMISSION_KOVOIT)
            montant_conducteur = montant - commission

            transref = payplus.generer_reference(reservation_id)

            try:
                data = payplus.initier_paiement(
                    phone=phone_number,
                    amount=montant,
                    operator=network,
                    transref=transref,
                    description=f'KoVoit — {trajet.depart} → {trajet.destination}',
                    notify_url=_NOTIFY_URL,
                )
            except payplus.PayPlusError as exc:
                logger.error('[Paiement] initier PayPlus error: %s (%s)', exc, exc.code)
                return Response({'error': str(exc)}, status=503)

            token = data.get('token') or data.get('transaction_id') or transref

            if paiement:
                paiement.montant          = montant
                paiement.moyen_paiement   = network
                paiement.statut           = Paiement.Statut.EN_ATTENTE
                paiement.reference_mobile = token
                paiement.save()
            else:
                paiement = Paiement.objects.create(
                    reservation=reservation,
                    passager=request.user,
                    conducteur=trajet.conducteur,
                    montant=montant,
                    moyen_paiement=network,
                    statut=Paiement.Statut.EN_ATTENTE,
                    reference_mobile=token,
                )

        operator_label = 'Moov Flooz' if network == 'FLOOZ' else 'Mixx by Yas'
        return Response({
            'message':             f'Paiement {operator_label} initié. Confirmez sur votre téléphone.',
            'token':               token,
            'transref':            transref,
            'montant':             montant,
            'commission_kovoit':   commission,
            'montant_conducteur':  montant_conducteur,
            'network':             network,
            'phone_number':        phone_number,
        }, status=201)

    # ── 2. Vérifier le statut d'un paiement ──────────────────────────────────
    @action(detail=False, methods=['post'])
    def verifier(self, request):
        """
        Vérifie le statut d'un paiement PayPlus Africa.
        Body: { token }
        """
        token = request.data.get('token') or request.data.get('identifier')
        if not token:
            return Response({'error': 'token requis.'}, status=400)

        try:
            data = payplus.verifier_statut(token)
        except payplus.PayPlusError as exc:
            return Response({'error': str(exc)}, status=503)

        # data["data"]["status"] = "SUCCESS" | "PENDING" | "FAILED"
        inner   = data.get('data') or data
        pp_status = (inner.get('status') or '').upper()

        if pp_status == 'SUCCESS':
            statut_label = 'payee'
            message      = 'Paiement réussi.'
        elif pp_status in ('PENDING', ''):
            statut_label = 'en_attente'
            message      = 'Paiement en cours de traitement.'
        else:
            statut_label = 'echouee'
            message      = inner.get('message') or 'Paiement échoué ou annulé.'

        # Mise à jour DB si paiement réussi
        if pp_status == 'SUCCESS':
            try:
                with transaction.atomic():
                    paiement = Paiement.objects.select_for_update().get(
                        reference_mobile=token,
                        reservation__passager=request.user,
                    )
                    if paiement.statut not in (Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE):
                        paiement.statut        = Paiement.Statut.PAYEE
                        paiement.date_payement = timezone.now()
                        paiement.save()
                        _notifier(request.user, 'Votre paiement a été confirmé.')
            except Paiement.DoesNotExist:
                logger.warning('[Paiement] verifier: token %s introuvable pour user %s', token, request.user)
            except Exception as exc:
                logger.error('[Paiement] verifier DB error: %s', exc)

        return Response({
            'statut':          statut_label,
            'message':         message,
            'pp_status':       pp_status,
            'token':           token,
            'phone':           inner.get('phone'),
            'amount':          inner.get('amount'),
            'payment_method':  inner.get('operator') or inner.get('payment_method'),
            'datetime':        inner.get('updated_at') or inner.get('created_at'),
        })

    # ── 3. Initier paiement en espèces ───────────────────────────────────────
    @action(detail=False, methods=['post'])
    def initier_especes(self, request):
        """
        Le passager initie un paiement en espèces.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({'error': 'reservation_id requis.'}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager'
            ).get(pk=reservation_id, passager=request.user)
        except Reservation.DoesNotExist:
            return Response({'error': 'Réservation introuvable.'}, status=404)

        if reservation.statut != 'confirmee':
            return Response({'error': 'La réservation doit être confirmée avant le paiement.'}, status=400)

        with transaction.atomic():
            try:
                existant = Paiement.objects.select_for_update().get(reservation=reservation)
                if existant.statut in (Paiement.Statut.CONFIRME, Paiement.Statut.EN_ATTENTE_CONFIRMATION):
                    return Response({'error': 'Un paiement existe déjà pour cette réservation.'}, status=400)
                existant.delete()
            except Paiement.DoesNotExist:
                pass

            trajet        = reservation.trajet
            prix_unitaire = float(reservation.prix_passager or trajet.prix_par_place or 0)
            montant       = reservation.places_reservees * prix_unitaire
            commission    = round(montant * COMMISSION_KOVOIT)

            paiement = Paiement.objects.create(
                reservation=reservation,
                passager=request.user,
                conducteur=trajet.conducteur,
                montant=montant,
                moyen_paiement='ESPECE',
                statut=Paiement.Statut.EN_ATTENTE_CONFIRMATION,
            )

        _notifier(
            request.user,
            'Paiement en espèces enregistré. Remettez le montant au conducteur lors du trajet.',
        )
        return Response({
            'message':             'Paiement en espèces initié. En attente de confirmation du conducteur.',
            'paiement_id':         paiement.id,
            'montant':             float(montant),
            'commission_kovoit':   commission,
            'montant_conducteur':  float(montant) - commission,
            'statut':              paiement.statut,
        }, status=201)

    # ── 4. Confirmer paiement en espèces (conducteur) ────────────────────────
    @action(detail=False, methods=['post'])
    def confirmer_especes(self, request):
        """
        Le conducteur confirme la réception du paiement en espèces.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({'error': 'reservation_id requis.'}, status=400)

        try:
            with transaction.atomic():
                try:
                    reservation = Reservation.objects.select_for_update().select_related(
                        'trajet', 'trajet__conducteur', 'passager'
                    ).get(pk=reservation_id, trajet__conducteur=request.user)
                except Reservation.DoesNotExist:
                    return Response(
                        {'error': "Réservation introuvable ou vous n'êtes pas le conducteur."},
                        status=404,
                    )

                try:
                    paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                except Paiement.DoesNotExist:
                    return Response({'error': 'Aucun paiement pour cette réservation.'}, status=404)

                if paiement.statut != Paiement.Statut.EN_ATTENTE_CONFIRMATION:
                    return Response({'error': f'Ce paiement n\'est pas en attente (statut: {paiement.statut}).'}, status=400)
                if paiement.moyen_paiement != 'ESPECE':
                    return Response({'error': "Ce n'est pas un paiement en espèces."}, status=400)

                paiement.statut            = Paiement.Statut.CONFIRME
                paiement.date_confirmation = timezone.now()
                paiement.save()

                logger.info('[Paiement] espèces confirmé paiement=%s conducteur=%s', paiement.id, request.user)

        except Exception as exc:
            logger.error('[Paiement] confirmer_especes error: %s', exc)
            return Response({'error': f'Erreur lors de la confirmation : {exc}'}, status=500)

        montant, commission, net = _calcul(paiement)
        _notifier(reservation.passager, 'Le conducteur a confirmé la réception de votre paiement en espèces.')

        return Response({
            'message':             'Paiement en espèces confirmé avec succès.',
            'paiement_id':         paiement.id,
            'reservation_id':      reservation.id,
            'montant':             montant,
            'commission_kovoit':   commission,
            'montant_conducteur':  net,
            'date_confirmation':   paiement.date_confirmation.isoformat(),
            'statut':              paiement.statut,
        })

    # ── 5. Statut de paiement d'une réservation ───────────────────────────────
    @action(detail=False, methods=['get'])
    def statut_reservation(self, request):
        """
        Retourne le statut de paiement d'une réservation.
        Query: ?reservation_id=X
        """
        reservation_id = request.query_params.get('reservation_id')
        if not reservation_id:
            return Response({'error': 'reservation_id requis.'}, status=400)

        try:
            reservation = Reservation.objects.select_related(
                'trajet', 'passager', 'trajet__conducteur'
            ).get(
                Q(passager=request.user) | Q(trajet__conducteur=request.user),
                pk=reservation_id,
            )
        except Reservation.DoesNotExist:
            return Response({'error': 'Réservation introuvable.'}, status=404)

        try:
            p = reservation.paiement
            return Response({
                'paiement_id':       p.id,
                'statut':            p.statut,
                'moyen_paiement':    p.moyen_paiement,
                'montant':           float(p.montant),
                'date_creation':     p.date_creation,
                'date_confirmation': p.date_confirmation,
            })
        except Paiement.DoesNotExist:
            return Response({'statut': 'AUCUN', 'message': 'Aucun paiement initié'})

    # ── 6. Mes paiements (passager) ───────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def mes_paiements(self, request):
        paiements = Paiement.objects.filter(
            reservation__passager=request.user
        ).select_related(
            'reservation', 'reservation__trajet'
        ).order_by('-date_creation')

        data = []
        for p in paiements:
            montant, commission, net = _calcul(p)
            trajet = p.reservation.trajet
            label = {
                'FLOOZ':  'Moov Flooz',
                'YAS':    'Mixx by Yas',
                'ESPECE': 'Espèces',
            }.get(p.moyen_paiement, p.moyen_paiement)

            data.append({
                'id':               p.id,
                'reservation_id':   p.reservation.id,
                'depart':           trajet.depart,
                'destination':      trajet.destination,
                'date_trajet':      trajet.date_heure_depart,
                'montant':          montant,
                'commission':       commission,
                'montant_net':      net,
                'moyen_paiement':   p.moyen_paiement,
                'operateur_label':  label,
                'statut':           p.statut,
                'date_paiement':    p.date_payement or p.date_confirmation or p.date_creation,
            })

        return Response(data)

    # ── 7. Paiements reçus par le conducteur ──────────────────────────────────
    @action(detail=False, methods=['get'])
    def paiements_conducteur(self, request):
        from datetime import datetime as dt

        qs = Paiement.objects.filter(
            conducteur=request.user,
            statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
        ).select_related(
            'reservation', 'reservation__trajet', 'reservation__passager'
        ).order_by('-date_creation')

        date_debut = request.query_params.get('date_debut')
        date_fin   = request.query_params.get('date_fin')
        mois       = request.query_params.get('mois')
        annee      = request.query_params.get('annee')

        if date_debut and date_fin:
            try:
                d1 = dt.strptime(date_debut, '%Y-%m-%d').date()
                d2 = dt.strptime(date_fin,   '%Y-%m-%d').date()
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__date__gte=d1, date_confirmation__date__lte=d2) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__date__gte=d1,     date_payement__date__lte=d2)
                )
            except ValueError:
                return Response({'error': 'Format date invalide (YYYY-MM-DD).'}, status=400)
        elif mois and annee:
            try:
                m, a = int(mois), int(annee)
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__year=a, date_confirmation__month=m) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__year=a,     date_payement__month=m)
                )
            except ValueError:
                return Response({'error': 'mois/annee invalides.'}, status=400)
        elif annee:
            try:
                a = int(annee)
                qs = qs.filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__year=a) |
                    Q(statut=Paiement.Statut.PAYEE,    date_payement__year=a)
                )
            except ValueError:
                return Response({'error': 'annee invalide.'}, status=400)

        data = []
        for p in qs:
            montant, commission, net = _calcul(p)
            resa    = p.reservation
            trajet  = resa.trajet
            passager = resa.passager
            date_eff = p.date_payement or p.date_confirmation or p.date_creation

            label = {
                'FLOOZ':  'Moov Flooz',
                'YAS':    'Mixx by Yas',
                'ESPECE': 'Espèces',
            }.get(p.moyen_paiement, p.moyen_paiement)

            data.append({
                'paiement_id':       p.id,
                'reservation_id':    resa.id,
                'depart':            trajet.depart,
                'destination':       trajet.destination,
                'date_trajet':       trajet.date_heure_depart.strftime('%Y-%m-%d') if trajet.date_heure_depart else None,
                'date_paiement':     date_eff.strftime('%Y-%m-%d') if date_eff else None,
                'passager_nom':      f'{passager.first_name} {passager.last_name}'.strip() or passager.username,
                'places':            resa.places_reservees,
                'montant_brut':      montant,
                'commission_kovoit': commission,
                'montant_net':       net,
                'taux_commission':   COMMISSION_KOVOIT,
                'moyen_paiement':    p.moyen_paiement,
                'operateur_label':   label,
                'statut':            p.statut,
            })

        total_brut       = sum(d['montant_brut']      for d in data)
        total_commission = sum(d['commission_kovoit']  for d in data)
        total_net        = sum(d['montant_net']        for d in data)

        return Response({
            'nombre':           len(data),
            'total_brut':       round(total_brut),
            'total_commission': round(total_commission),
            'total_net':        round(total_net),
            'taux_commission':  COMMISSION_KOVOIT,
            'paiements':        data,
        })

    # ── 8. Webhook PayPlus Africa (confirmation automatique) ──────────────────
    @action(detail=False, methods=['post'], permission_classes=[])
    def webhook(self, request):
        """
        Endpoint appelé par PayPlus Africa après paiement réussi.

        Sécurité :
          - Vérification signature HMAC-SHA256 (X-PayPlus-Signature).
          - Idempotent : un paiement déjà confirmé répond 200 sans re-traitement.
          - Validation montant serveur.
          - select_for_update anti race-condition.
          - Retourne 500 pour forcer le retry PayPlus en cas d'erreur inattendue.
        """
        # ── Vérification de signature ─────────────────────────────────────
        signature = request.headers.get('X-PayPlus-Signature', '')
        if signature:
            raw_body = request._request.body
            if not payplus.verifier_signature_webhook(raw_body, signature):
                logger.warning('[Webhook] signature invalide IP=%s', request.META.get('REMOTE_ADDR'))
                return Response(status=403)

        # ── Lecture des données ───────────────────────────────────────────
        # PayPlus envoie : {"type": "COLLECTION", "status": "SUCCESS", "transref": "KOVOIT-xxx", ...}
        pp_status = (request.data.get('status') or '').upper()
        transref  = request.data.get('transref') or request.data.get('reference', '')

        if not transref:
            return Response({'error': 'transref manquant'}, status=400)

        # Extraire reservation_id depuis "KOVOIT-{id}-{hash}"
        try:
            parts = transref.split('-')
            if len(parts) < 3 or parts[0] != 'KOVOIT':
                raise ValueError('format invalide')
            reservation_id = parts[1]
        except (ValueError, IndexError):
            logger.warning('[Webhook] transref malformé : %s', transref)
            return Response({'error': 'transref invalide'}, status=400)

        # ── Traitement selon le statut ────────────────────────────────────
        if pp_status not in ('SUCCESS', 'FAILED', 'FAILED_OPERATOR'):
            # PENDING ou autre statut intermédiaire → on attend
            logger.debug('[Webhook] statut ignoré : %s', pp_status)
            return Response({'status': 'ok'})

        try:
            with transaction.atomic():
                try:
                    reservation = Reservation.objects.select_for_update().select_related(
                        'trajet', 'passager'
                    ).get(pk=reservation_id)
                except Reservation.DoesNotExist:
                    logger.warning('[Webhook] réservation %s introuvable', reservation_id)
                    return Response({'status': 'ok'})

                try:
                    paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                except Paiement.DoesNotExist:
                    logger.warning('[Webhook] aucun paiement pour réservation %s', reservation_id)
                    return Response({'status': 'ok'})

                # Idempotence
                if paiement.statut in (Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE):
                    return Response({'status': 'ok'})

                if pp_status == 'SUCCESS':
                    # Validation montant
                    montant_recu = request.data.get('amount')
                    if montant_recu is not None:
                        try:
                            if Decimal(str(montant_recu)) != paiement.montant:
                                logger.error(
                                    '[Webhook] montant incohérent paiement=%s reçu=%s attendu=%s',
                                    paiement.id, montant_recu, paiement.montant,
                                )
                                return Response({'error': 'montant incohérent'}, status=400)
                        except (InvalidOperation, TypeError):
                            pass

                    paiement.statut        = Paiement.Statut.PAYEE
                    paiement.date_payement = timezone.now()
                    paiement.reference_mobile = (
                        request.data.get('token') or paiement.reference_mobile
                    )
                    paiement.save()
                    logger.info('[Webhook] paiement %s confirmé pour réservation %s', paiement.id, reservation_id)
                    _notifier(reservation.passager, 'Votre paiement a été confirmé.')

                else:
                    paiement.statut = Paiement.Statut.ECHOUEE
                    paiement.save()
                    logger.info('[Webhook] paiement %s échoué pour réservation %s', paiement.id, reservation_id)
                    _notifier(reservation.passager, 'Le paiement a échoué. Veuillez réessayer.')

        except Exception as exc:
            logger.error('[Webhook] erreur inattendue : %s', exc)
            return Response(status=500)

        return Response({'status': 'ok'})

    # ── 9. Annuler / Rembourser un paiement ───────────────────────────────────
    @action(detail=False, methods=['post'])
    def annuler_paiement(self, request):
        """
        Le passager annule son paiement Mobile Money en attente.
        Body: { reservation_id }
        """
        reservation_id = request.data.get('reservation_id')
        if not reservation_id:
            return Response({'error': 'reservation_id requis.'}, status=400)

        try:
            with transaction.atomic():
                reservation = Reservation.objects.select_related(
                    'trajet', 'passager'
                ).get(pk=reservation_id, passager=request.user)

                try:
                    paiement = Paiement.objects.select_for_update().get(reservation=reservation)
                except Paiement.DoesNotExist:
                    return Response({'error': 'Aucun paiement pour cette réservation.'}, status=404)

                if paiement.statut in (Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE):
                    return Response({'error': 'Impossible d\'annuler un paiement déjà confirmé.'}, status=400)

                paiement.statut = Paiement.Statut.ANNULE
                paiement.save()

        except Reservation.DoesNotExist:
            return Response({'error': 'Réservation introuvable.'}, status=404)
        except Exception as exc:
            return Response({'error': str(exc)}, status=500)

        return Response({'message': 'Paiement annulé.', 'statut': Paiement.Statut.ANNULE})
