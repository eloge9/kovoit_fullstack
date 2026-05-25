"""
Tests pour l'API d'administration KoVoit
"""
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.test import TestCase, Client
from django.contrib.auth import get_user_model
from apps.modeles.models import Utilisateur, Conducteur, Vehicule, Trajet, Plainte
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class AdminAPITestCase(TestCase):
    """Test des endpoints d'administration"""
    
    def setUp(self):
        """Créer les données de test"""
        # Admin
        self.admin = Utilisateur.objects.create_user(
            username='admin',
            email='admin@test.com',
            password='admin123',
            role='admin'
        )
        
        # Conducteur
        self.conducteur = Utilisateur.objects.create_user(
            username='driver',
            email='driver@test.com',
            password='driver123',
            role='conducteur',
            is_active=False  # Pour tester la validation
        )
        
        # Profil conducteur
        self.profil_cond = Conducteur.objects.create(
            utilisateur=self.conducteur,
            numero_permis='PERM123456',
            experience_annees=5
        )
        
        # Véhicule
        self.vehicule = Vehicule.objects.create(
            conducteur=self.profil_cond,
            type_vehicule='voiture',
            marque='Toyota',
            modele='Corolla',
            couleur='Gris',
            plaque='AB-123-CD',
            places_max=5
        )
        
        # Passager
        self.passager = Utilisateur.objects.create_user(
            username='passenger',
            email='pass@test.com',
            password='pass123',
            role='passager'
        )
        
        # Client API
        self.client = APIClient()
        
        # Token admin
        refresh = RefreshToken.for_user(self.admin)
        self.admin_token = str(refresh.access_token)
    
    def test_admin_peut_valider_conducteur(self):
        """Test: Admin peut valider un conducteur"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        # Avant: conducteur inactif
        self.conducteur.refresh_from_db()
        self.assertFalse(self.conducteur.is_active)
        
        # Valider
        response = self.client.post(
            f'/api/utilisateurs/admin/utilisateurs/{self.conducteur.id}/valider-conducteur/',
            format='json'
        )
        
        # Après: conducteur actif
        self.assertEqual(response.status_code, 200)
        self.conducteur.refresh_from_db()
        self.assertTrue(self.conducteur.is_active)
    
    def test_admin_peut_lister_utilisateurs(self):
        """Test: Admin peut lister tous les utilisateurs"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        response = self.client.get('/api/utilisateurs/admin/utilisateurs/')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 3)  # admin, conducteur, passager
    
    def test_admin_peut_filtrer_par_role(self):
        """Test: Admin peut filtrer les utilisateurs par rôle"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        response = self.client.get('/api/utilisateurs/admin/utilisateurs/?role=conducteur')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['role'], 'conducteur')
    
    def test_admin_peut_suspendre_utilisateur(self):
        """Test: Admin peut suspendre un utilisateur"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        # Activer d'abord le conducteur
        self.conducteur.is_active = True
        self.conducteur.save()
        
        # Suspendre
        response = self.client.post(
            f'/api/utilisateurs/admin/utilisateurs/{self.conducteur.id}/suspendre/',
            format='json'
        )
        
        self.assertEqual(response.status_code, 200)
        self.conducteur.refresh_from_db()
        self.assertFalse(self.conducteur.is_active)
    
    def test_admin_peut_voir_statistiques(self):
        """Test: Admin peut voir les statistiques globales"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        response = self.client.get('/api/utilisateurs/admin/statistiques/')
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('nombre_utilisateurs_total', response.data)
        self.assertIn('nombre_conducteurs', response.data)
        self.assertIn('nombre_trajets_total', response.data)
    
    def test_non_admin_ne_peut_pas_acceder(self):
        """Test: Non-admin ne peut pas accéder aux endpoints d'admin"""
        # Token passager
        refresh = RefreshToken.for_user(self.passager)
        token = str(refresh.access_token)
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/utilisateurs/admin/utilisateurs/')
        
        # Devrait retourner 403 ou 401
        self.assertIn(response.status_code, [401, 403])
    
    def test_plainte_creation_et_gestion(self):
        """Test: Gestion des plaintes"""
        plainte = Plainte.objects.create(
            titre="Conducteur agressif",
            description="Test",
            type_plainte='comportement',
            signalataire=self.passager,
            utilisateur_signale=self.conducteur
        )
        
        self.assertEqual(plainte.statut, 'en_attente')
        self.assertIsNone(plainte.admin_assigne)
        
        # Admin assigne la plainte
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        response = self.client.post(
            f'/api/utilisateurs/admin/plaintes/{plainte.id}/assigner/',
            format='json'
        )
        
        self.assertEqual(response.status_code, 200)
        plainte.refresh_from_db()
        self.assertEqual(plainte.admin_assigne, self.admin)
        self.assertEqual(plainte.statut, 'en_cours')


if __name__ == '__main__':
    import unittest
    unittest.main()
