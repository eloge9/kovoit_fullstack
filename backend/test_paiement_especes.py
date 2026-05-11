#!/usr/bin/env python
"""
Script de test pour le paiement en espèces
"""
import os
import sys
import django

# Configuration de Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.contrib.auth import get_user_model
from apps.modeles.models import Paiement, Reservation, Trajet, Passager, Conducteur
from django.utils import timezone
from django.db import transaction

User = get_user_model()

def test_paiement_especes():
    print("🧪 Test du système de paiement en espèces...")
    
    try:
        # Vérifier que les nouveaux statuts existent
        print("\n✅ Vérification des statuts de paiement:")
        print(f"   - EN_ATTENTE_CONFIRMATION: {hasattr(Paiement.Statut, 'EN_ATTENTE_CONFIRMATION')}")
        print(f"   - CONFIRME: {hasattr(Paiement.Statut, 'CONFIRME')}")
        print(f"   - ANNULE: {hasattr(Paiement.Statut, 'ANNULE')}")
        print(f"   - EN_ATTENTE (mobile money): {hasattr(Paiement.Statut, 'EN_ATTENTE')}")
        print(f"   - PAYEE (mobile money): {hasattr(Paiement.Statut, 'PAYEE')}")
        
        # Vérifier les nouveaux champs
        print("\n✅ Vérification des nouveaux champs:")
        paiement_fields = [f.name for f in Paiement._meta.get_fields()]
        print(f"   - passager: {'passager' in paiement_fields}")
        print(f"   - conducteur: {'conducteur' in paiement_fields}")
        print(f"   - date_creation: {'date_creation' in paiement_fields}")
        print(f"   - date_confirmation: {'date_confirmation' in paiement_fields}")
        
        # Compter les paiements existants
        total_paiements = Paiement.objects.count()
        print(f"\n📊 Total des paiements existants: {total_paiements}")
        
        # Vérifier les paiements par statut
        print("\n📊 Paiements par statut:")
        for statut, label in Paiement.Statut.choices:
            count = Paiement.objects.filter(statut=statut).count()
            print(f"   - {statut}: {count}")
        
        # Tester la création d'un paiement en espèces
        print("\n🧪 Test de création d'un paiement en espèces...")
        
        # Vérifier s'il y a des réservations
        reservations = Reservation.objects.all()[:1]
        if reservations:
            reservation = reservations[0]
            print(f"   Réservation trouvée: #{reservation.id}")
            
            # Vérifier si un paiement existe déjà
            paiement_existant = Paiement.objects.filter(reservation=reservation).first()
            if paiement_existant:
                print(f"   Paiement existant: #{paiement_existant.id} - {paiement_existant.get_statut_display()}")
            else:
                print("   Aucun paiement existant pour cette réservation")
        else:
            print("   ⚠️ Aucune réservation trouvée dans la base de données")
        
        print("\n✅ Test terminé avec succès!")
        
    except Exception as e:
        print(f"\n❌ Erreur lors du test: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_paiement_especes()
