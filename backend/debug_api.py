#!/usr/bin/env python
"""
Script de debug pour l'API de paiement
"""
import os
import sys
import django
import requests

# Configuration de Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.contrib.auth import get_user_model
from apps.modeles.models import Paiement, Reservation, Trajet, Passager, Conducteur

User = get_user_model()

def debug_api():
    print("🔍 Debug API Paiement...")
    
    try:
        # Vérifier les réservations existantes
        reservations = Reservation.objects.all()[:3]
        print(f"\n📋 Réservations trouvées: {len(reservations)}")
        
        for res in reservations:
            print(f"   - Réservation #{res.id}: Passager={res.passager}, Trajet={res.trajet.id}")
            
            # Vérifier si un paiement existe
            try:
                paiement = res.paiement
                print(f"     💳 Paiement existant: {paiement.id} - {paiement.statut} - {paiement.moyen_paiement}")
            except Paiement.DoesNotExist:
                print(f"     ❌ Aucun paiement")
        
        # Test de l'API sans authentification
        print(f"\n🌐 Test API statut_reservation...")
        
        if reservations:
            reservation_id = reservations[0].id
            url = f"http://localhost:8000/api/paiements/statut_reservation/?reservation_id={reservation_id}"
            
            try:
                response = requests.get(url)
                print(f"   Status: {response.status_code}")
                print(f"   Response: {response.text}")
            except requests.exceptions.ConnectionError:
                print(f"   ❌ Erreur de connexion - le serveur Django est-il démarré ?")
            except Exception as e:
                print(f"   ❌ Erreur: {e}")
        
    except Exception as e:
        print(f"\n❌ Erreur lors du debug: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    debug_api()
