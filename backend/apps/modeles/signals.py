"""
Signals Django pour la gestion automatique des statuts conducteur.
Déclenché après chaque sauvegarde d'un Utilisateur.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Utilisateur, Conducteur, Passager


@receiver(post_save, sender=Utilisateur)
def gerer_validation_conducteur(sender, instance, created, **kwargs):
    """
    Quand l'admin valide les documents (statut_validation → 'valide') :
    - Activer le compte si ce n'est pas déjà fait
    - Marquer peut_conduire = True pour autoriser le double rôle
    - Créer le profil Passager s'il n'existe pas (pour permettre le basculement)

    Quand les documents sont rejetés :
    - Remettre peut_conduire = False
    """
    # Utiliser update_fields pour éviter les boucles infinies
    update_fields = []

    if instance.statut_validation == 'valide' and not instance.peut_conduire:
        update_fields.append('peut_conduire')
        Utilisateur.objects.filter(pk=instance.pk).update(peut_conduire=True)

        # Créer le profil Passager si absent (pour permettre le double rôle)
        if not Passager.objects.filter(utilisateur=instance).exists():
            Passager.objects.create(utilisateur=instance)

    elif instance.statut_validation == 'rejete' and instance.peut_conduire:
        Utilisateur.objects.filter(pk=instance.pk).update(peut_conduire=False)
