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

from ..modeles.commission import taux_commission
from ..modeles.models import (
    DepotWallet, Notification, Paiement, Reservation, Wallet, WalletTransaction, Withdrawal,
)
from . import payplus_service as payplus
from . import wallet_service

logger = logging.getLogger(__name__)

# URL de notification par défaut (override via settings.PAYPLUS_NOTIFY_URL)
_NOTIFY_URL   = getattr(settings, 'PAYPLUS_NOTIFY_URL', 'https://kovoit.com/api/paiements/webhook/')
_FRONTEND_URL = getattr(settings, 'FRONTEND_URL', 'https://kovoit.com')


# ─────────────────────────────────────────────────────────────────────────────
def _notifier(utilisateur, contenu: str):
    """Crée une notification en base pour l'utilisateur."""
    try:
        Notification.objects.create(utilisateur=utilisateur, contenu=contenu)
    except Exception as exc:
        logger.warning('[Paiement] notification skipped: %s', exc)


def _calcul(paiement: Paiement) -> tuple[float, float, float]:
    montant    = float(paiement.montant)
    commission = round(montant * float(taux_commission()))
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
            commission         = round(montant * float(taux_commission()))
            montant_conducteur = montant - commission

            transref = payplus.generer_reference(reservation_id)

            try:
                data = payplus.creer_facture(
                    phone=phone_number,
                    amount=montant,
                    description=f'KoVoit — {trajet.depart} → {trajet.destination}',
                    transref=transref,
                    notify_url=_NOTIFY_URL,
                    return_url=f'{_FRONTEND_URL}/passager/reservations/paiement/{reservation_id}',
                    cancel_url=f'{_FRONTEND_URL}/passager/reservations/paiement/{reservation_id}',
                    website_url=_FRONTEND_URL,
                )
            except payplus.PayPlusError as exc:
                logger.error('[Paiement] initier PayPlus error: %s (%s)', exc, exc.code)
                return Response({'error': str(exc)}, status=503)

            token = data['token']

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
            'message':             f'Paiement {operator_label} initié. Ouvrez le lien pour confirmer.',
            'token':               token,
            'transref':            transref,
            'payment_url':         data['payment_url'],
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

        # Vérifier que le token appartient bien à un paiement de l'utilisateur courant
        # avant tout appel PayPlus (évite l'exposition des données d'un tiers)
        if not Paiement.objects.filter(
            reference_mobile=token,
            reservation__passager=request.user,
        ).exists():
            return Response({'error': 'Paiement introuvable.'}, status=404)

        try:
            data = payplus.verifier_facture(token)
        except payplus.PayPlusError as exc:
            return Response({'error': str(exc)}, status=503)

        # description: 'pending' | 'completed' | 'notcompleted' | 'inconnu'
        pp_statut = data['statut']

        if pp_statut == 'completed':
            statut_label = 'payee'
            message      = 'Paiement réussi.'
        elif pp_statut == 'pending':
            statut_label = 'en_attente'
            message      = 'Paiement en cours de traitement.'
        else:
            statut_label = 'echouee'
            message      = 'Paiement échoué ou annulé.'

        # Mise à jour DB si paiement réussi
        if pp_statut == 'completed':
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
            'statut':      statut_label,
            'message':     message,
            'pp_statut':   pp_statut,
            'token':       token,
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
            commission    = round(montant * float(taux_commission()))

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
            logger.error('[Paiement] confirmer_especes error: %s', exc, exc_info=True)
            return Response({'error': 'Erreur interne. Veuillez réessayer.'}, status=500)

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

        taux = float(taux_commission())
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
                'taux_commission':   taux,
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
            'taux_commission':  taux,
            'paiements':        data,
        })

    # ── 8. Webhook PayPlus Africa (confirmation automatique) ──────────────────
    @action(detail=False, methods=['post'], permission_classes=[])
    def webhook(self, request):
        """
        Endpoint appelé par PayPlus Africa (callback_url) après paiement.

        Le format exact du corps du callback checkout-invoice n'est pas
        documenté publiquement — plutôt que de lui faire confiance, ce
        webhook ne sert que de déclencheur : il identifie la transaction via
        `transref` (transmis dans l'URL de callback_url à la création, donc
        garanti par nous) puis revérifie le statut auprès de PayPlus via
        verifier_facture(), seule source de vérité.

        Sécurité :
          - Vérification signature HMAC-SHA256 (X-PayPlus-Signature) si configurée.
          - Idempotent : un paiement déjà confirmé répond 200 sans re-traitement.
          - select_for_update anti race-condition.
          - Retourne 500 pour forcer le retry PayPlus en cas d'erreur inattendue.
        """
        webhook_secret = getattr(settings, 'PAYPLUS_WEBHOOK_SECRET', '')
        if webhook_secret:
            signature = request.headers.get('X-PayPlus-Signature', '')
            if not signature:
                logger.warning('[Webhook] signature absente IP=%s', request.META.get('REMOTE_ADDR'))
                return Response(status=403)
            raw_body = request._request.body
            if not payplus.verifier_signature_webhook(raw_body, signature):
                logger.warning('[Webhook] signature invalide IP=%s', request.META.get('REMOTE_ADDR'))
                return Response(status=403)

        transref = request.query_params.get('transref', '')
        if not transref:
            return Response({'error': 'transref manquant'}, status=400)

        try:
            parts = transref.split('-')
            if len(parts) < 3 or parts[0] != 'KOVOIT':
                raise ValueError('format invalide')
            if parts[1] == 'WALLET':
                if len(parts) < 4:
                    raise ValueError('format invalide')
                return self._traiter_webhook_depot(transref)
            reservation_id = parts[1]
        except (ValueError, IndexError):
            logger.warning('[Webhook] transref malformé : %s', transref)
            return Response({'error': 'transref invalide'}, status=400)

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
                if not paiement.reference_mobile:
                    logger.warning('[Webhook] paiement %s sans token PayPlus', paiement.id)
                    return Response({'status': 'ok'})

                try:
                    verif = payplus.verifier_facture(paiement.reference_mobile)
                except payplus.PayPlusError as exc:
                    logger.error('[Webhook] verifier_facture échec paiement=%s: %s', paiement.id, exc)
                    return Response(status=500)

                if verif['statut'] == 'completed':
                    paiement.statut        = Paiement.Statut.PAYEE
                    paiement.date_payement = timezone.now()
                    paiement.save()
                    logger.info('[Webhook] paiement %s confirmé pour réservation %s', paiement.id, reservation_id)
                    _notifier(reservation.passager, 'Votre paiement a été confirmé.')
                elif verif['statut'] == 'notcompleted':
                    paiement.statut = Paiement.Statut.ECHOUEE
                    paiement.save()
                    logger.info('[Webhook] paiement %s échoué pour réservation %s', paiement.id, reservation_id)
                    _notifier(reservation.passager, 'Le paiement a échoué. Veuillez réessayer.')
                else:
                    logger.debug('[Webhook] paiement %s toujours en attente (%s)', paiement.id, verif['statut'])

        except Exception as exc:
            logger.error('[Webhook] erreur inattendue : %s', exc)
            return Response(status=500)

        return Response({'status': 'ok'})

    def _traiter_webhook_depot(self, transref):
        """
        Branche du webhook pour un dépôt wallet (transref KOVOIT-WALLET-{wallet_id}-{hash}).
        Le montant crédité est celui mémorisé sur DepotWallet à la création
        de la facture — jamais celui d'un corps de webhook non fiable.
        """
        try:
            depot = DepotWallet.objects.select_for_update().select_related('wallet').get(transref=transref)
        except DepotWallet.DoesNotExist:
            logger.warning('[Webhook] dépôt introuvable pour transref=%s', transref)
            return Response({'status': 'ok'})

        if depot.statut != DepotWallet.Statut.EN_ATTENTE:
            return Response({'status': 'ok'})

        try:
            verif = payplus.verifier_facture(depot.token)
        except payplus.PayPlusError as exc:
            logger.error('[Webhook] verifier_facture échec dépôt=%s: %s', depot.id, exc)
            return Response(status=500)

        if verif['statut'] == 'completed':
            try:
                wallet_service.deposer(
                    wallet=depot.wallet, montant=depot.montant,
                    reference=f'DEPOT-{depot.transref}',
                    description='Dépôt Mobile Money',
                )
                depot.statut            = DepotWallet.Statut.CONFIRME
                depot.date_confirmation = timezone.now()
                depot.save(update_fields=['statut', 'date_confirmation'])
                if depot.wallet.proprietaire:
                    _notifier(
                        depot.wallet.proprietaire,
                        f'Votre dépôt de {depot.montant} FCFA a été crédité sur votre portefeuille.',
                    )
            except Exception as exc:
                logger.error('[Webhook] erreur crédit dépôt=%s: %s', depot.id, exc, exc_info=True)
                return Response(status=500)
        elif verif['statut'] == 'notcompleted':
            depot.statut = DepotWallet.Statut.ECHOUE
            depot.save(update_fields=['statut'])

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
            logger.error('[Paiement] annuler_paiement error: %s', exc, exc_info=True)
            return Response({'error': 'Erreur interne. Veuillez réessayer.'}, status=500)

        return Response({'message': 'Paiement annulé.', 'statut': Paiement.Statut.ANNULE})


def _serialiser_transaction(t: WalletTransaction) -> dict:
    return {
        'id':               t.id,
        'type':             t.type,
        'sens':             t.sens,
        'montant':          float(t.montant),
        'solde_disponible_apres': float(t.solde_disponible_apres),
        'solde_du_apres':         float(t.solde_du_apres),
        'statut':           t.statut,
        'description':      t.description,
        'created_at':       t.created_at,
    }


def _serialiser_retrait(r: Withdrawal) -> dict:
    return {
        'id':                   r.id,
        'montant':              float(r.montant),
        'moyen':                r.moyen,
        'numero_destination':   r.numero_destination,
        'statut':               r.statut,
        'motif_echec':          r.motif_echec,
        'date_demande':         r.date_demande,
        'date_traitement':      r.date_traitement,
    }


# ─────────────────────────────────────────────────────────────────────────────
class WalletViewSet(viewsets.GenericViewSet):
    """
    Portefeuille conducteur : solde, historique, dépôt (Mobile Money), retrait.

    Le retrait est traité manuellement par un administrateur (voir
    apps.utilisateurs.admin_views) — PayPlus Africa n'expose pas d'API de
    payout programmable vers un numéro tiers, seulement un retrait marchand
    depuis leur portail (KoVoit → son propre compte).
    """
    permission_classes = [IsAuthenticated]

    def _wallet_du_conducteur(self, request):
        if request.user.role != 'conducteur':
            return None
        return Wallet.pour(request.user)

    # ── 1. Mon wallet ─────────────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='mon_wallet')
    def mon_wallet(self, request):
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)
        return Response({
            'solde_disponible': float(wallet.solde_disponible),
            'solde_du':         float(wallet.solde_du),
            'peut_retirer':     wallet.solde_du == 0 and wallet.solde_disponible > 0,
        })

    # ── 2. Historique des transactions ───────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='mes_transactions')
    def mes_transactions(self, request):
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)
        qs = wallet.transactions.all()[:200]
        return Response([_serialiser_transaction(t) for t in qs])

    # ── 3. Initier un dépôt Mobile Money ─────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='deposer_initier')
    def deposer_initier(self, request):
        """Body: { montant, phone_number, network ('FLOOZ' | 'YAS') }"""
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)

        try:
            montant = Decimal(str(request.data.get('montant')))
        except (InvalidOperation, TypeError):
            return Response({'error': 'montant invalide.'}, status=400)
        if montant <= 0:
            return Response({'error': 'montant invalide.'}, status=400)

        phone_number = (request.data.get('phone_number') or '').strip()
        network      = (request.data.get('network') or '').upper()
        if not phone_number:
            return Response({'error': 'phone_number requis.'}, status=400)
        if network not in ('FLOOZ', 'YAS'):
            return Response({'error': "network doit être 'FLOOZ' (Moov Flooz) ou 'YAS' (Mixx by Yas)."}, status=400)

        transref = f'KOVOIT-WALLET-{wallet.id}-{uuid.uuid4().hex[:10]}'
        try:
            data = payplus.creer_facture(
                phone=phone_number,
                amount=int(montant),
                description='KoVoit — Dépôt portefeuille',
                transref=transref,
                notify_url=_NOTIFY_URL,
                return_url=f'{_FRONTEND_URL}/conducteur/portefeuille',
                cancel_url=f'{_FRONTEND_URL}/conducteur/portefeuille',
                website_url=_FRONTEND_URL,
            )
        except payplus.PayPlusError as exc:
            logger.error('[Wallet] deposer_initier PayPlus error: %s (%s)', exc, exc.code)
            return Response({'error': str(exc)}, status=503)

        DepotWallet.objects.create(
            wallet=wallet, montant=montant, token=data['token'], transref=transref,
        )

        return Response({
            'message':     'Dépôt initié. Ouvrez le lien pour confirmer.',
            'token':       data['token'],
            'transref':    transref,
            'payment_url': data['payment_url'],
            'montant':     float(montant),
        }, status=201)

    # ── 4. Vérifier / confirmer un dépôt (fallback si le webhook tarde) ──────
    @action(detail=False, methods=['post'], url_path='deposer_verifier')
    def deposer_verifier(self, request):
        """Body: { token, transref }"""
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)

        token    = request.data.get('token')
        transref = request.data.get('transref') or ''
        if not token:
            return Response({'error': 'token requis.'}, status=400)

        with transaction.atomic():
            try:
                depot = DepotWallet.objects.select_for_update().get(
                    token=token, transref=transref, wallet=wallet,
                )
            except DepotWallet.DoesNotExist:
                return Response({'error': 'Dépôt introuvable.'}, status=404)

            if depot.statut == DepotWallet.Statut.CONFIRME:
                wallet.refresh_from_db()
                return Response({
                    'statut':           'confirme',
                    'message':          'Dépôt crédité avec succès.',
                    'solde_disponible': float(wallet.solde_disponible),
                    'solde_du':         float(wallet.solde_du),
                })

            try:
                verif = payplus.verifier_facture(token)
            except payplus.PayPlusError as exc:
                return Response({'error': str(exc)}, status=503)

            if verif['statut'] == 'notcompleted':
                depot.statut = DepotWallet.Statut.ECHOUE
                depot.save(update_fields=['statut'])
                return Response({'statut': 'echouee', 'message': 'Dépôt échoué ou annulé.'})
            if verif['statut'] != 'completed':
                return Response({'statut': 'en_attente', 'message': 'Dépôt en cours de traitement.'})

            wallet_service.deposer(
                wallet=wallet, montant=depot.montant,
                reference=f'DEPOT-{depot.transref}',
                description='Dépôt Mobile Money',
            )
            depot.statut            = DepotWallet.Statut.CONFIRME
            depot.date_confirmation = timezone.now()
            depot.save(update_fields=['statut', 'date_confirmation'])

        wallet.refresh_from_db()
        return Response({
            'statut':            'confirme',
            'message':           'Dépôt crédité avec succès.',
            'solde_disponible':  float(wallet.solde_disponible),
            'solde_du':          float(wallet.solde_du),
        })

    # ── 5. Demander un retrait ────────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='retirer')
    def retirer(self, request):
        """Body: { montant, moyen ('FLOOZ' | 'YAS'), numero_destination }"""
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)

        try:
            montant = Decimal(str(request.data.get('montant')))
        except (InvalidOperation, TypeError):
            return Response({'error': 'montant invalide.'}, status=400)

        moyen              = (request.data.get('moyen') or '').upper()
        numero_destination = (request.data.get('numero_destination') or '').strip()
        if moyen not in ('FLOOZ', 'YAS'):
            return Response({'error': "moyen doit être 'FLOOZ' ou 'YAS'."}, status=400)
        if not numero_destination:
            return Response({'error': 'numero_destination requis.'}, status=400)

        try:
            retrait = wallet_service.demander_retrait(
                wallet=wallet, montant=montant, moyen=moyen,
                numero_destination=numero_destination,
            )
        except wallet_service.DetteEnCoursError as exc:
            return Response({'error': str(exc)}, status=400)
        except wallet_service.SoldeInsuffisantError as exc:
            return Response({'error': str(exc)}, status=400)
        except ValueError as exc:
            return Response({'error': str(exc)}, status=400)

        return Response({
            'message': 'Demande de retrait enregistrée. Traitement sous 24 à 48h.',
            'retrait': _serialiser_retrait(retrait),
        }, status=201)

    # ── 6. Mes retraits ───────────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='mes_retraits')
    def mes_retraits(self, request):
        wallet = self._wallet_du_conducteur(request)
        if wallet is None:
            return Response({'error': 'Réservé aux conducteurs.'}, status=403)
        qs = wallet.retraits.all()[:100]
        return Response([_serialiser_retrait(r) for r in qs])
