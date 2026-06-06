"""
Signaux pour l'app paiements
Déclenche les actions automatiques lors de changements de paiement
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from apps.modeles.models import Paiement
from apps.statistiques.services import actualiser_statistiques_economie


@receiver(post_save, sender=Paiement)
def paiement_post_save(sender, instance, created, **kwargs):
    """
    Signal déclenché quand un paiement est créé ou modifié.
    Met à jour les statistiques économiques si le paiement est confirmé.
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


# Enregistrer le signal quand cette app est prête
def ready():
    """À appeler dans apps.py"""
    pass
