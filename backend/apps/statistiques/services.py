"""
Services pour calculer les statistiques économiques de KoVoit
"""
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import date, timedelta
from calendar import monthrange
from decimal import Decimal

from apps.modeles.models import (
    StatistiqueEconomie, Paiement, Trajet, Reservation, Utilisateur
)


COMMISSION_KOVOIT = Decimal('0.10')  # 10%
COUT_CARBURANT_PAR_KM = {
    'moto': 30,
    'voiture': 65,
    'minibus': 120,
    'camion': 200,
}


def calculer_stats_economie_conducteur(utilisateur, periode_debut, periode_fin):
    """
    Calcule les statistiques économiques pour un conducteur sur une période.
    
    Args:
        utilisateur: Utilisateur (conducteur)
        periode_debut: date de début
        periode_fin: date de fin
    
    Returns:
        dict: dictionnaire avec les statistiques
    """
    # Filtrer les paiements confirmés du conducteur
    paiements = Paiement.objects.filter(
        conducteur=utilisateur,
        statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
        date_confirmation__gte=periode_debut,
        date_confirmation__lte=periode_fin
    )
    
    total_revenus = paiements.aggregate(total=Sum('montant'))['total'] or Decimal('0')
    total_paiements = paiements.count()
    
    # Calculer les trajets terminés
    trajets = Trajet.objects.filter(
        conducteur=utilisateur,
        date_heure_depart__gte=periode_debut,
        date_heure_depart__lte=periode_fin,
        statut='termine'
    )
    
    total_trajets = trajets.count()
    total_km = trajets.aggregate(total=Sum('distance_km'))['total'] or 0
    
    # Moyenne par trajet
    moyenne_par_trajet = total_revenus / total_trajets if total_trajets > 0 else Decimal('0')
    
    return {
        'total_revenus': total_revenus,
        'total_trajets': total_trajets,
        'total_km': total_km,
        'moyenne_par_trajet': moyenne_par_trajet,
        'nombre_paiements': total_paiements,
    }


def calculer_stats_economie_passager(utilisateur, periode_debut, periode_fin):
    """
    Calcule les statistiques économiques (économies) pour un passager sur une période.
    
    Args:
        utilisateur: Utilisateur (passager)
        periode_debut: date de début
        periode_fin: date de fin
    
    Returns:
        dict: dictionnaire avec les statistiques
    """
    # Récupérer toutes les réservations confirmées/terminées
    reservations = Reservation.objects.filter(
        passager=utilisateur,
        statut__in=['confirmee', 'terminee'],
        date_reservation__gte=periode_debut,
        date_reservation__lte=periode_fin
    ).select_related('trajet', 'trajet__vehicule')
    
    total_reservations = reservations.count()
    
    # Somme des montants payés
    montants_payes = Paiement.objects.filter(
        passager=utilisateur,
        statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
        date_confirmation__gte=periode_debut,
        date_confirmation__lte=periode_fin
    ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
    
    total_economies = montants_payes  # Le passager paye moins qu'un taxi
    moyenne_par_reservation = total_economies / total_reservations if total_reservations > 0 else Decimal('0')
    
    # Calcul économie carburant (si passager avait pris voiture personnelle)
    total_km = reservations.aggregate(total=Sum('trajet__distance_km'))['total'] or 0
    economie_carburant = Decimal(total_km * 65) / 4  # Approximation: voiture à 65/km, 4 passagers
    
    # CO2 évité (1kg CO2 par 5km en voiture personnelle)
    co2_evite = total_km / 5
    
    return {
        'total_economies': total_economies,
        'total_reservations': total_reservations,
        'moyenne_par_reservation': moyenne_par_reservation,
        'economie_carburant': economie_carburant,
        'co2_evite': co2_evite,
        'total_km': total_km,
    }


def actualiser_statistiques_economie(utilisateur, periode_debut=None, periode_fin=None):
    """
    Recalcule et sauvegarde les statistiques économiques pour un utilisateur.
    
    Args:
        utilisateur: Utilisateur
        periode_debut: date de début (optionnel, par défaut début du mois)
        periode_fin: date de fin (optionnel, par défaut fin du mois)
    
    Returns:
        StatistiqueEconomie: objet statistique créé/mis à jour
    """
    if periode_debut is None:
        today = date.today()
        periode_debut = date(today.year, today.month, 1)
    
    if periode_fin is None:
        today = date.today()
        last_day = monthrange(today.year, today.month)[1]
        periode_fin = date(today.year, today.month, last_day)
    
    # Déterminer si conducteur ou passager
    if utilisateur.role == 'conducteur':
        stats_dict = calculer_stats_economie_conducteur(utilisateur, periode_debut, periode_fin)
        
        stats, created = StatistiqueEconomie.objects.update_or_create(
            utilisateur=utilisateur,
            periode_debut=periode_debut,
            periode_fin=periode_fin,
            defaults={
                'total_revenus': stats_dict['total_revenus'],
                'total_trajets': stats_dict['total_trajets'],
                'total_km': stats_dict['total_km'],
                'moyenne_par_trajet': stats_dict['moyenne_par_trajet'],
            }
        )
    else:  # Passager
        stats_dict = calculer_stats_economie_passager(utilisateur, periode_debut, periode_fin)
        
        stats, created = StatistiqueEconomie.objects.update_or_create(
            utilisateur=utilisateur,
            periode_debut=periode_debut,
            periode_fin=periode_fin,
            defaults={
                'total_economies': stats_dict['total_economies'],
                'total_reservations': stats_dict['total_reservations'],
                'moyenne_par_reservation': stats_dict['moyenne_par_reservation'],
                'economie_carburant': stats_dict['economie_carburant'],
                'co2_evite': stats_dict['co2_evite'],
            }
        )
    
    return stats


def actualiser_stats_tous_utilisateurs():
    """
    Recalcule les statistiques pour tous les utilisateurs (à appeler par Celery).
    """
    today = date.today()
    periode_debut = date(today.year, today.month, 1)
    last_day = monthrange(today.year, today.month)[1]
    periode_fin = date(today.year, today.month, last_day)
    
    utilisateurs = Utilisateur.objects.filter(
        role__in=['conducteur', 'passager']
    )
    
    results = {
        'updated': 0,
        'created': 0,
        'errors': 0,
    }
    
    for user in utilisateurs:
        try:
            stats = actualiser_statistiques_economie(user, periode_debut, periode_fin)
            if stats:
                results['updated'] += 1
        except Exception as e:
            results['errors'] += 1
            print(f"Erreur pour {user.username}: {str(e)}")
    
    return results
