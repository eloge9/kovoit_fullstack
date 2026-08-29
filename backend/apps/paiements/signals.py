"""
Signaux pour l'app paiements
Déclenche les actions automatiques lors de changements de paiement
"""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from apps.modeles.models import Paiement
from apps.statistiques.services import actualiser_statistiques_economie

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Paiement)
def paiement_post_save(sender, instance, created, **kwargs):
    """
    Signal déclenché quand un paiement est créé ou modifié.
    Met à jour les statistiques économiques et le wallet du conducteur
    si le paiement est confirmé.

    Idempotent côté wallet : chaque écriture est identifiée par une
    reference unique dérivée de paiement.id, donc un re-déclenchement de
    ce signal (le paiement peut être resauvegardé plus tard) ne crédite/
    débite jamais deux fois.
    """
    # Seulement si le paiement passe à CONFIRME ou PAYEE
    if instance.statut in [Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE]:
        try:
            # Mettre à jour les stats du conducteur
            if instance.conducteur:
                actualiser_statistiques_economie(instance.conducteur)

            # Mettre à jour les stats du passager
            if instance.passager:
                actualiser_statistiques_economie(instance.passager)
        except Exception as e:
            print(f"Erreur lors de la mise à jour des statistiques: {str(e)}")

        try:
            from .wallet_service import crediter_paiement_electronique, crediter_paiement_especes_dette
            if instance.moyen_paiement == 'ESPECE':
                crediter_paiement_especes_dette(instance)
            else:
                crediter_paiement_electronique(instance)
        except Exception as e:
            logger.error('[Wallet] échec crédit wallet pour paiement=%s: %s', instance.id, e, exc_info=True)


# Enregistrer le signal quand cette app est prête
def ready():
    """À appeler dans apps.py"""
    pass
