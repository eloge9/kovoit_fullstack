"""
WalletService — unique point d'écriture sur les soldes Wallet.

Règles :
  - Aucune vue, signal ou tâche ne modifie Wallet.solde_disponible / solde_du
    directement : tout passe par les fonctions de ce module.
  - Chaque écriture crée une ligne WalletTransaction (ledger append-only) et
    est idempotente sur son `reference` : rejouer le même appel (webhook
    dupliqué, retry, signal déclenché deux fois) ne débite/crédite qu'une fois.
  - Toute mutation de solde se fait sous select_for_update(), dans une
    transaction atomique, à l'image du webhook PayPlus existant.
"""
import logging
from decimal import Decimal

from django.db import transaction

from ..modeles.commission import taux_commission
from ..modeles.models import Paiement, Wallet, WalletTransaction, Withdrawal

logger = logging.getLogger(__name__)


class WalletError(Exception):
    """Erreur métier wallet (jamais une erreur de programmation)."""


class SoldeInsuffisantError(WalletError):
    pass


class DetteEnCoursError(WalletError):
    pass


# ─────────────────────────────────────────────────────────────────────────────
# Primitive interne — jamais appelée hors de ce module.
def _appliquer(*, wallet, type_, sens, montant, reference, description='',
                delta_disponible=Decimal('0'), delta_du=Decimal('0'),
                paiement=None, reservation=None, retrait=None, cree_par=None):
    montant = Decimal(montant)
    if montant <= 0:
        raise ValueError('Le montant doit être strictement positif.')

    with transaction.atomic():
        existante = WalletTransaction.objects.filter(reference=reference).first()
        if existante is not None:
            logger.info('[Wallet] transaction déjà appliquée, no-op: %s', reference)
            return existante

        w = Wallet.objects.select_for_update().get(pk=wallet.pk)

        solde_disponible_avant = w.solde_disponible
        solde_du_avant         = w.solde_du

        nouveau_disponible = solde_disponible_avant + delta_disponible
        nouveau_du          = solde_du_avant + delta_du

        if nouveau_disponible < 0:
            raise SoldeInsuffisantError(
                f"Solde disponible insuffisant ({solde_disponible_avant} < {-delta_disponible})."
            )
        if nouveau_du < 0:
            nouveau_du = Decimal('0')

        w.solde_disponible = nouveau_disponible
        w.solde_du          = nouveau_du
        w.save(update_fields=['solde_disponible', 'solde_du', 'date_maj'])

        return WalletTransaction.objects.create(
            wallet=w, type=type_, sens=sens, montant=montant,
            solde_disponible_avant=solde_disponible_avant,
            solde_disponible_apres=nouveau_disponible,
            solde_du_avant=solde_du_avant,
            solde_du_apres=nouveau_du,
            statut=WalletTransaction.Statut.REUSSI,
            reference=reference, description=description,
            paiement=paiement, reservation=reservation, retrait=retrait,
            cree_par=cree_par,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Crédit conducteur après paiement électronique (FLOOZ / YAS) confirmé.
def crediter_paiement_electronique(paiement: Paiement):
    if paiement.moyen_paiement == 'ESPECE':
        return None
    if paiement.statut not in (Paiement.Statut.PAYEE, Paiement.Statut.CONFIRME):
        return None
    if not paiement.conducteur:
        return None

    montant    = Decimal(paiement.montant)
    commission = (montant * taux_commission()).quantize(Decimal('1'))
    net        = montant - commission

    conducteur_wallet = Wallet.pour(paiement.conducteur)
    plateforme_wallet = Wallet.plateforme()

    with transaction.atomic():
        credit = _appliquer(
            wallet=conducteur_wallet,
            type_=WalletTransaction.Type.RIDE_PAYMENT_CREDIT,
            sens=WalletTransaction.Sens.CREDIT,
            montant=net,
            reference=f'RIDE_CREDIT-{paiement.id}',
            description=f'Paiement trajet — réservation #{paiement.reservation_id}',
            delta_disponible=net,
            paiement=paiement, reservation=paiement.reservation,
        )
        if commission > 0:
            _appliquer(
                wallet=plateforme_wallet,
                type_=WalletTransaction.Type.COMMISSION_ELECTRONIC,
                sens=WalletTransaction.Sens.CREDIT,
                montant=commission,
                reference=f'COMMISSION_ELEC-{paiement.id}',
                description=f'Commission trajet — réservation #{paiement.reservation_id}',
                delta_disponible=commission,
                paiement=paiement, reservation=paiement.reservation,
            )
    return credit


# ─────────────────────────────────────────────────────────────────────────────
# Reprise involontaire (annulation après crédit) — contrairement à _appliquer,
# ne bloque jamais : le déficit éventuel (argent déjà retiré) devient une dette.
def _clawback(*, wallet, montant, type_, reference, description='', paiement=None, reservation=None):
    montant = Decimal(montant)
    if montant <= 0:
        raise ValueError('Le montant doit être strictement positif.')

    with transaction.atomic():
        existante = WalletTransaction.objects.filter(reference=reference).first()
        if existante is not None:
            return existante

        w = Wallet.objects.select_for_update().get(pk=wallet.pk)

        solde_disponible_avant = w.solde_disponible
        solde_du_avant         = w.solde_du

        pris_sur_disponible = min(montant, solde_disponible_avant)
        deficit             = montant - pris_sur_disponible

        w.solde_disponible = solde_disponible_avant - pris_sur_disponible
        w.solde_du          = solde_du_avant + deficit
        w.save(update_fields=['solde_disponible', 'solde_du', 'date_maj'])

        return WalletTransaction.objects.create(
            wallet=w, type=type_, sens=WalletTransaction.Sens.DEBIT, montant=montant,
            solde_disponible_avant=solde_disponible_avant, solde_disponible_apres=w.solde_disponible,
            solde_du_avant=solde_du_avant, solde_du_apres=w.solde_du,
            statut=WalletTransaction.Statut.REUSSI,
            reference=reference, description=description,
            paiement=paiement, reservation=reservation,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Annulation d'une réservation déjà payée électroniquement : reprend le crédit
# conducteur + la commission plateforme. La pénalité (si applicable) reste
# acquise au conducteur en compensation. Le solde restant doit être remboursé
# au passager PAR UN ADMINISTRATEUR : PayPlus Africa ne documente aucune API
# de remboursement/reversal publique (même lacune que pour les retraits).
def annuler_paiement_electronique(paiement: Paiement, penalite=Decimal('0')):
    if paiement.moyen_paiement == 'ESPECE':
        return None
    if paiement.statut not in (Paiement.Statut.PAYEE, Paiement.Statut.CONFIRME):
        return None
    if not paiement.conducteur:
        return None

    montant    = Decimal(paiement.montant)
    commission = (montant * taux_commission()).quantize(Decimal('1'))
    net        = montant - commission
    penalite   = min(Decimal(penalite or 0), net)

    conducteur_wallet = Wallet.pour(paiement.conducteur)
    plateforme_wallet = Wallet.plateforme()

    with transaction.atomic():
        _clawback(
            wallet=conducteur_wallet, montant=net,
            type_=WalletTransaction.Type.REFUND,
            reference=f'RIDE_REFUND-{paiement.id}',
            description=f'Annulation réservation #{paiement.reservation_id} — reprise du crédit',
            paiement=paiement, reservation=paiement.reservation,
        )
        if commission > 0:
            _clawback(
                wallet=plateforme_wallet, montant=commission,
                type_=WalletTransaction.Type.REFUND,
                reference=f'COMMISSION_REFUND-{paiement.id}',
                description=f'Annulation réservation #{paiement.reservation_id} — reprise commission',
                paiement=paiement, reservation=paiement.reservation,
            )
        if penalite > 0:
            _appliquer(
                wallet=conducteur_wallet,
                type_=WalletTransaction.Type.CANCELLATION_PENALTY,
                sens=WalletTransaction.Sens.CREDIT,
                montant=penalite,
                reference=f'CANCELLATION_PENALTY-{paiement.id}',
                description=f"Pénalité d'annulation tardive — réservation #{paiement.reservation_id}",
                delta_disponible=penalite,
                paiement=paiement, reservation=paiement.reservation,
            )

    paiement.statut = Paiement.Statut.REMBOURSE
    paiement.save(update_fields=['statut'])

    return {
        'montant_paye':               montant,
        'penalite_conducteur':        penalite,
        'a_rembourser_passager':      montant - penalite,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Dette de commission sur un paiement espèces confirmé par le conducteur.
def crediter_paiement_especes_dette(paiement: Paiement):
    if paiement.moyen_paiement != 'ESPECE':
        return None
    if paiement.statut != Paiement.Statut.CONFIRME:
        return None
    if not paiement.conducteur:
        return None

    montant    = Decimal(paiement.montant)
    commission = (montant * taux_commission()).quantize(Decimal('1'))
    if commission <= 0:
        return None

    conducteur_wallet = Wallet.pour(paiement.conducteur)
    return _appliquer(
        wallet=conducteur_wallet,
        type_=WalletTransaction.Type.COMMISSION_CASH_DUE,
        sens=WalletTransaction.Sens.DEBIT,
        montant=commission,
        reference=f'CASH_COMMISSION_DUE-{paiement.id}',
        description=f'Commission due (espèces) — réservation #{paiement.reservation_id}',
        delta_du=commission,
        paiement=paiement, reservation=paiement.reservation,
    )


# ─────────────────────────────────────────────────────────────────────────────
# Dépôt conducteur : règle la dette en premier, le surplus alimente le disponible.
def deposer(*, wallet: Wallet, montant, reference: str, description='',
            paiement=None, cree_par=None):
    montant = Decimal(montant)
    if montant <= 0:
        raise ValueError('Montant de dépôt invalide.')

    resultats = []
    with transaction.atomic():
        w = Wallet.objects.select_for_update().get(pk=wallet.pk)
        montant_dette      = min(montant, w.solde_du)
        montant_disponible = montant - montant_dette

        if montant_dette > 0:
            resultats.append(_appliquer(
                wallet=w,
                type_=WalletTransaction.Type.COMMISSION_CASH_SETTLED,
                sens=WalletTransaction.Sens.DEBIT,
                montant=montant_dette,
                reference=f'{reference}-SETTLE',
                description=description or 'Règlement de la commission due',
                delta_du=-montant_dette,
                paiement=paiement, cree_par=cree_par,
            ))
        if montant_disponible > 0:
            resultats.append(_appliquer(
                wallet=w,
                type_=WalletTransaction.Type.DEPOSIT,
                sens=WalletTransaction.Sens.CREDIT,
                montant=montant_disponible,
                reference=f'{reference}-DEPOT' if montant_dette > 0 else reference,
                description=description or 'Dépôt',
                delta_disponible=montant_disponible,
                paiement=paiement, cree_par=cree_par,
            ))
    return resultats


# ─────────────────────────────────────────────────────────────────────────────
# Retrait conducteur — débit immédiat à la demande pour bloquer le double-retrait.
def demander_retrait(*, wallet: Wallet, montant, moyen: str, numero_destination: str):
    montant = Decimal(montant)
    if montant <= 0:
        raise ValueError('Montant de retrait invalide.')

    with transaction.atomic():
        w = Wallet.objects.select_for_update().get(pk=wallet.pk)
        if w.solde_du > 0:
            raise DetteEnCoursError(
                "Impossible de retirer : une commission reste due à KoVoit."
            )
        if w.solde_disponible < montant:
            raise SoldeInsuffisantError('Solde disponible insuffisant.')

        retrait = Withdrawal.objects.create(
            wallet=w, montant=montant, moyen=moyen,
            numero_destination=numero_destination,
            statut=Withdrawal.Statut.EN_ATTENTE,
        )
        _appliquer(
            wallet=w,
            type_=WalletTransaction.Type.WITHDRAWAL_REQUEST,
            sens=WalletTransaction.Sens.DEBIT,
            montant=montant,
            reference=f'WITHDRAWAL_REQUEST-{retrait.id}',
            description=f'Demande de retrait vers {numero_destination}',
            delta_disponible=-montant,
            retrait=retrait,
        )
    return retrait


def completer_retrait(*, retrait: Withdrawal, reference_agregateur='', admin=None):
    from django.utils import timezone

    with transaction.atomic():
        r = Withdrawal.objects.select_for_update().get(pk=retrait.pk)
        if r.statut not in (Withdrawal.Statut.EN_ATTENTE, Withdrawal.Statut.EN_COURS):
            return r

        r.statut               = Withdrawal.Statut.REUSSI
        r.reference_agregateur = reference_agregateur
        r.traite_par            = admin
        r.date_traitement       = timezone.now()
        r.save(update_fields=['statut', 'reference_agregateur', 'traite_par', 'date_traitement'])

        # Trace de statut uniquement : le débit a déjà eu lieu à la demande.
        _appliquer(
            wallet=r.wallet,
            type_=WalletTransaction.Type.WITHDRAWAL_COMPLETED,
            sens=WalletTransaction.Sens.DEBIT,
            montant=r.montant,
            reference=f'WITHDRAWAL_COMPLETED-{r.id}',
            description=f'Retrait effectué vers {r.numero_destination}',
            retrait=r, cree_par=admin,
        )
    return r


def echouer_retrait(*, retrait: Withdrawal, motif='', admin=None):
    from django.utils import timezone

    with transaction.atomic():
        r = Withdrawal.objects.select_for_update().get(pk=retrait.pk)
        if r.statut in (Withdrawal.Statut.REUSSI, Withdrawal.Statut.ECHOUE, Withdrawal.Statut.ANNULE):
            return r

        r.statut          = Withdrawal.Statut.ECHOUE
        r.motif_echec      = motif
        r.traite_par        = admin
        r.date_traitement   = timezone.now()
        r.save(update_fields=['statut', 'motif_echec', 'traite_par', 'date_traitement'])

        # Remboursement du montant réservé à la demande.
        _appliquer(
            wallet=r.wallet,
            type_=WalletTransaction.Type.WITHDRAWAL_FAILED,
            sens=WalletTransaction.Sens.CREDIT,
            montant=r.montant,
            reference=f'WITHDRAWAL_FAILED-{r.id}',
            description=(f'Retrait échoué — remboursement ({motif})' if motif else 'Retrait échoué — remboursement'),
            delta_disponible=r.montant,
            retrait=r, cree_par=admin,
        )
    return r


# ─────────────────────────────────────────────────────────────────────────────
# Correction manuelle — admin uniquement, motif et traçabilité obligatoires.
def ajustement_manuel(*, wallet: Wallet, montant, description: str, admin, reference: str):
    if not description:
        raise ValueError('Un motif est obligatoire pour un ajustement manuel.')
    if not admin:
        raise ValueError('Un ajustement manuel doit être attribué à un administrateur.')

    montant = Decimal(montant)
    if montant == 0:
        raise ValueError('Montant d\'ajustement invalide.')

    sens = WalletTransaction.Sens.CREDIT if montant > 0 else WalletTransaction.Sens.DEBIT
    return _appliquer(
        wallet=wallet,
        type_=WalletTransaction.Type.ADJUSTMENT,
        sens=sens,
        montant=abs(montant),
        reference=reference,
        description=description,
        delta_disponible=montant,
        cree_par=admin,
    )
