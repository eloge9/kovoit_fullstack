import os
import django
import requests
import json

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken

# Récupérer l'utilisateur
User = get_user_model()
user = User.objects.get(email='gominaeloge@gmail.com')

# Générer un token JWT
refresh = RefreshToken.for_user(user)
access_token = str(refresh.access_token)

print(f"Test API avec période 'tous' pour {user.username}")

# Tester l'API avec période "tous"
headers = {
    'Authorization': f'Bearer {access_token}',
    'Content-Type': 'application/json'
}

try:
    response = requests.get('http://127.0.0.1:8000/api/statistiques/passager/?periode=annee&annee=2026', headers=headers)
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"total_economies: {data.get('total_economies', 'N/A')}")
        print(f"total_reservations: {data.get('total_reservations', 'N/A')}")
        print(f"economie_moyenne_reservation: {data.get('economie_moyenne_reservation', 'N/A')}")
        print(f"co2_total_evite: {data.get('co2_total_evite', 'N/A')}")
        
        # Afficher la dernière réservation si elle existe
        derniere = data.get('derniere_reservation')
        if derniere:
            print(f"derniere_reservation: {derniere}")
        else:
            print("derniere_reservation: Aucune")
            
    else:
        print(f"Erreur: {response.text}")
        
except Exception as e:
    print(f"Exception: {e}")
