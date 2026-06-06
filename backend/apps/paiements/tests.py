"""
Tests unitaires pour les paiements en espèces et les statistiques
"""
from django.test import TestCase, TransactionTestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from decimal import Decimal
from datetime import datetime, timedelta

from apps.modeles.models import (
    Utilisateur, Trajet, Reservation, Paiement, Vehicule, Conducteur
)
from apps.statistiques.services import actualiser_statistiques_economie

User = get_user_model()


class PaiementEspecesTestCase(TransactionTestCase):
    """Tests pour les paiements en espèces"""
    
    def setUp(self):
        """Créer les données de test"""
        # Créer un conducteur
        self.conducteur = Utilisateur.objects.create_user(
            username='conducteur1',
            email='conducteur@test.com',
            password='pass123',
            role='conducteur'
        )
        
        # Créer un profil conducteur
        self.conducteur_profil = Conducteur.objects.create(
            utilisateur=self.conducteur,
            numero_permis='CM123456',
            experience_annees=5
        )
        
        # Créer un véhicule
        self.vehicule = Vehicule.objects.create(
            conducteur=self.conducteur_profil,
            type_vehicule='voiture',
            marque='Toyota',
            modele='Corolla',
            couleur='Blanc',
            plaque='CM-1234',
            places_max=5
        )
        
        # Créer un passager
        self.passager = Utilisateur.objects.create_user(
            username='passager1',
            email='passager@test.com',
            password='pass123',
            role='passager'
        )
        
        # Créer un trajet
        self.trajet = Trajet.objects.create(
            conducteur=self.conducteur,
            vehicule=self.vehicule,
            depart='Yaoundé',
            destination='Douala',
            depart_lat=3.8667,
            depart_lng=11.5167,
            destination_lat=4.0511,
            destination_lng=9.7679,
            distance_km=250,
            prix_par_place=Decimal('5000'),
            date_heure_depart=timezone.now() + timedelta(days=1),
            places_disponibles=4,
            statut='ouvert'
        )
    
    def test_initier_paiement_especes(self):
        """Test l'initiation d'un paiement en espèces"""
        # Créer une réservation confirmée
        reservation = Reservation.objects.create(
            trajet=self.trajet,
            passager=self.passager,
            places_reservees=1,
            statut='confirmee'
        )
        
        # Initier un paiement en espèces
        paiement = Paiement.objects.create(
            reservation=reservation,
            passager=self.passager,
            conducteur=self.conducteur,
            montant=Decimal('5000'),
            moyen_paiement='ESPECE',
            statut=Paiement.Statut.EN_ATTENTE_CONFIRMATION
        )
        
        # Vérifier que le paiement est bien créé
        self.assertEqual(paiement.statut, Paiement.Statut.EN_ATTENTE_CONFIRMATION)
        self.assertEqual(paiement.montant, Decimal('5000'))
        self.assertEqual(paiement.moyen_paiement, 'ESPECE')
        print("✓ Paiement en espèces initié avec succès")
    
    def test_confirmer_paiement_especes(self):
        """Test la confirmation d'un paiement en espèces"""
        # Créer une réservation et un paiement
        reservation = Reservation.objects.create(
            trajet=self.trajet,
            passager=self.passager,
            places_reservees=1,
            statut='confirmee'
        )
        
        paiement = Paiement.objects.create(
            reservation=reservation,
            passager=self.passager,
            conducteur=self.conducteur,
            montant=Decimal('5000'),
            moyen_paiement='ESPECE',
            statut=Paiement.Statut.EN_ATTENTE_CONFIRMATION
        )
        
        # Confirmer le paiement
        paiement.statut = Paiement.Statut.CONFIRME
        paiement.date_confirmation = timezone.now()
        paiement.save()
        
        # Vérifier que le paiement est confirmé
        paiement.refresh_from_db()
        self.assertEqual(paiement.statut, Paiement.Statut.CONFIRME)
        self.assertIsNotNone(paiement.date_confirmation)
        print("✓ Paiement en espèces confirmé avec succès")
    
    def test_statistiques_apres_paiement(self):
        """Test que les statistiques sont mises à jour après un paiement"""
        # Créer une réservation et un paiement confirmé
        reservation = Reservation.objects.create(
            trajet=self.trajet,
            passager=self.passager,
            places_reservees=1,
            statut='confirmee'
        )
        
        paiement = Paiement.objects.create(
            reservation=reservation,
            passager=self.passager,
            conducteur=self.conducteur,
            montant=Decimal('5000'),
            moyen_paiement='ESPECE',
            statut=Paiement.Statut.CONFIRME,
            date_confirmation=timezone.now()
        )
        
        # Recalculer les stats du conducteur
        stats = actualiser_statistiques_economie(self.conducteur)
        
        # Vérifier que les stats ont été mises à jour
        self.assertIsNotNone(stats)
        print(f"✓ Statistiques conducteur mise à jour: {stats.total_revenus} FCFA")
        
        # Recalculer les stats du passager
        stats_passager = actualiser_statistiques_economie(self.passager)
        self.assertIsNotNone(stats_passager)
        print(f"✓ Statistiques passager mise à jour: {stats_passager.total_economies} FCFA")
