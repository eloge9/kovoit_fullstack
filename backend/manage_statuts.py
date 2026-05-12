#!/usr/bin/env python
"""
Script de vérification et correction des incohérences de statuts
entre les trajets et les réservations.

Usage:
    python manage_statuts.py [--auto-correct]
    --auto-correct: Corrige automatiquement les incohérences trouvées
"""

import os
import sys
import django

# Configuration Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from apps.modeles.models import Trajet, Reservation
from django.db import models


def verifier_incoherences():
    """Vérifie les incohérences entre statuts de trajets et réservations"""
    print("=== Vérification des incohérences de statuts ===\n")
    
    # Statuts possibles pour les trajets et réservations
    trajet_stats = dict(Trajet.objects.values_list('statut').annotate(count=models.Count('statut')))
    reservation_stats = dict(Reservation.objects.values_list('statut').annotate(count=models.Count('statut')))
    
    print("Statuts des trajets:")
    for statut, count in trajet_stats.items():
        print(f"  {statut}: {count}")
    
    print("\nStatuts des réservations:")
    for statut, count in reservation_stats.items():
        print(f"  {statut}: {count}")
    
    print("\n" + "="*50)
    
    # Rechercher les incohérences
    incoherences = []
    
    # 1. Trajets terminés avec réservations non confirmées
    trajets_termines = Trajet.objects.filter(statut='termine')
    for trajet in trajets_termines:
        reservations_non_confirmees = Reservation.objects.filter(
            trajet=trajet
        ).exclude(statut='confirmee')
        
        if reservations_non_confirmees.exists():
            incoherences.append({
                'type': 'trajet_termine_reservation_non_confirmee',
                'trajet': trajet,
                'reservations': reservations_non_confirmees
            })
    
    # 2. Trajets ouverts avec réservations confirmées (incohérent)
    trajets_ouverts = Trajet.objects.filter(statut='ouvert')
    for trajet in trajets_ouverts:
        reservations_confirmees = Reservation.objects.filter(
            trajet=trajet,
            statut='confirmee'
        )
        
        if reservations_confirmees.exists():
            incoherences.append({
                'type': 'trajet_ouvert_reservation_confirmee',
                'trajet': trajet,
                'reservations': reservations_confirmees
            })
    
    # Afficher les résultats
    print(f"\nIncohérences trouvées: {len(incoherences)}\n")
    
    for i, incoh in enumerate(incoherences, 1):
        trajet = incoh['trajet']
        print(f"Incohérence {i}:")
        print(f"  Type: {inhom['type']}")
        print(f"  Trajet: {trajet.depart} → {trajet.destination}")
        print(f"  Statut trajet: {trajet.statut}")
        print(f"  Réservations concernées:")
        for res in incoh['reservations']:
            print(f"    - Réservation {res.id}: {res.passager.username} (statut: {res.statut})")
        print()
    
    return incoherences


def corriger_incoherences(incoherences):
    """Corrige les incohérences trouvées"""
    print("=== Correction des incohérences ===\n")
    
    corrections = 0
    
    for incoh in incoherences:
        trajet = incoh['trajet']
        
        if incoh['type'] == 'trajet_termine_reservation_non_confirmee':
            print(f"Trajet terminé: {trajet.depart} → {trajet.destination}")
            
            # Mettre les réservations à 'confirmee'
            for res in incoh['reservations']:
                print(f"  Correction réservation {res.id}: {res.statut} -> confirmee")
                res.statut = 'confirmee'
                res.save()
                corrections += 1
                
        elif incoh['type'] == 'trajet_ouvert_reservation_confirmee':
            print(f"Trajet ouvert: {trajet.depart} → {trajet.destination}")
            
            # Mettre les réservations à 'en_attente' ou un autre statut approprié
            for res in incoh['reservations']:
                print(f"  Correction réservation {res.id}: {res.statut} -> en_attente")
                res.statut = 'en_attente'
                res.save()
                corrections += 1
    
    print(f"\nTotal corrections effectuées: {corrections}")
    return corrections


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Vérifier et corriger les incohérences de statuts')
    parser.add_argument('--auto-correct', action='store_true', 
                       help='Corriger automatiquement les incohérences')
    
    args = parser.parse_args()
    
    try:
        incoherences = verifier_incoherences()
        
        if incoherences:
            if args.auto_correct:
                corriger_incoherences(incoherences)
                print("\n✅ Corrections appliquées avec succès!")
            else:
                print("\n💡 Utilisez --auto-correct pour appliquer les corrections automatiquement")
        else:
            print("\n✅ Aucune incohérence trouvée!")
            
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
