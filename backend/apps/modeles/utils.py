"""
Utilitaires pour les calculs économiques du passager
"""
from decimal import Decimal

def calculer_economie_passager(distance_km, type_vehicule, prix_kovoit_place):
    """
    Calcule l'économie réalisée par un passager en utilisant Kovoit
    par rapport à une course privée (Gozem/Taxi)
    
    Formule: Gain = Prix_Gozem - Prix_Kovoit
    
    Args:
        distance_km (float): Distance du trajet en kilomètres
        type_vehicule (str): Type de véhicule ('moto', 'voiture', 'minibus', 'camion')
        prix_kovoit_place (float): Prix par place sur Kovoit
        
    Returns:
        dict: Dictionnaire contenant les détails du calcul
    """
    # Conversion en Decimal pour éviter les erreurs d'arrondi
    distance_km = Decimal(str(distance_km))
    prix_kovoit_place = Decimal(str(prix_kovoit_place))
    
    # 1. Calcul du prix qu'il aurait payé en course privée (Gozem/Taxi)
    if type_vehicule == 'moto':
        # Référence Gozem pour moto: Distance × 100 FCFA
        prix_reference = distance_km * Decimal('100')
    else:
        # Référence Taxi pour Voiture, Minibus et Camion: 500 + (Distance × 275)
        prix_reference = Decimal('500') + (distance_km * Decimal('275'))
    
    # 2. Calcul de l'économie
    gain = prix_reference - prix_kovoit_place
    
    # 3. Calcul du pourcentage d'économie
    if prix_reference > 0:
        pourcentage_economie = (gain / prix_reference) * Decimal('100')
    else:
        pourcentage_economie = Decimal('0')
    
    return {
        'distance_km': float(distance_km),
        'type_vehicule': type_vehicule,
        'prix_kovoit_place': float(prix_kovoit_place),
        'prix_reference': float(prix_reference),
        'economie': float(gain),
        'pourcentage_economie': float(pourcentage_economie),
        'reference_type': 'Gozem' if type_vehicule == 'moto' else 'Taxi'
    }


def calculer_economie_mensuelle_passager(reservations):
    """
    Calcule les économies totales d'un passager sur une période donnée
    
    Args:
        reservations (QuerySet): Réservations confirmées du passager
        
    Returns:
        dict: Statistiques économiques mensuelles
    """
    total_economie = 0
    total_depense_kovoit = 0
    total_depense_reference = 0
    details_reservations = []
    
    for reservation in reservations:
        if reservation.statut in ['confirmee', 'terminee'] and reservation.trajet.distance_km:
            trajet = reservation.trajet
            prix_kovoit = float(trajet.prix_par_place) * reservation.places_reservees
            
            # Calculer l'économie pour cette réservation
            type_vehicule = trajet.vehicule.type_vehicule if trajet.vehicule else 'voiture'
            calc = calculer_economie_passager(
                trajet.distance_km,
                type_vehicule,
                float(trajet.prix_par_place)
            )
            
            # Adapter pour le nombre de places réservées
            economie_reservation = calc['economie'] * reservation.places_reservees
            prix_reference_reservation = calc['prix_reference'] * reservation.places_reservees
            
            total_economie += economie_reservation
            total_depense_kovoit += prix_kovoit
            total_depense_reference += prix_reference_reservation
            
            # Calculer le pourcentage d'économie
            pourcentage_economie = 0
            if prix_reference_reservation > 0:
                pourcentage_economie = (economie_reservation / prix_reference_reservation) * 100
            
            details_reservations.append({
                'reservation_id': reservation.id,
                'trajet': f"{trajet.depart} → {trajet.destination}",
                'date': reservation.date_reservation.strftime('%Y-%m-%d'),
                'distance_km': trajet.distance_km,
                'type_vehicule': type_vehicule,
                'places_reservees': reservation.places_reservees,
                'prix_kovoit_total': prix_kovoit,
                'prix_reference_total': prix_reference_reservation,
                'economie': economie_reservation,
                'pourcentage_economie': round(pourcentage_economie, 1),
                'reference_type': 'Gozem' if type_vehicule == 'moto' else 'Taxi'
            })
    
    return {
        'total_economie': round(total_economie, 2),
        'total_depense_kovoit': round(total_depense_kovoit, 2),
        'total_depense_reference': round(total_depense_reference, 2),
        'nombre_reservations': len(details_reservations),
        'economie_moyenne_reservation': round(total_economie / len(details_reservations), 2) if details_reservations else 0,
        'details_reservations': details_reservations
    }


def get_tarif_reference_gozem(distance_km, type_vehicule):
    """
    Retourne le tarif de référence Gozem/Taxi selon le type de véhicule
    
    Args:
        distance_km (float): Distance en km
        type_vehicule (str): Type de véhicule
        
    Returns:
        float: Prix de référence en FCFA
    """
    distance_km = Decimal(str(distance_km))
    
    if type_vehicule == 'moto':
        return float(distance_km * Decimal('100'))
    else:
        return float(Decimal('500') + (distance_km * Decimal('275')))
