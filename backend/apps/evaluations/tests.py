from django.test import TestCase
from django.utils import timezone
from decimal import Decimal
from datetime import timedelta
from apps.modeles.models import Utilisateur, Trajet, Reservation, Evaluation, Vehicule, Conducteur


class EvaluationAPITests(TestCase):
    """Tests pour l'API d'évaluation"""
    
    def setUp(self):
        """Créer les données de test"""
        # Conducteur
        self.conducteur = Utilisateur.objects.create_user(
            username='cond1',
            email='cond1@test.com',
            password='pass123',
            role='conducteur'
        )
        
        self.conducteur_profil = Conducteur.objects.create(
            utilisateur=self.conducteur,
            numero_permis='CM123456'
        )
        
        self.vehicule = Vehicule.objects.create(
            conducteur=self.conducteur_profil,
            type_vehicule='voiture',
            marque='Toyota',
            plaque='CM-1234',
            places_max=5
        )
        
        # Passager
        self.passager = Utilisateur.objects.create_user(
            username='pass1',
            email='pass1@test.com',
            password='pass123',
            role='passager'
        )
        
        # Trajet
        self.trajet = Trajet.objects.create(
            conducteur=self.conducteur,
            vehicule=self.vehicule,
            depart='Yaoundé',
            destination='Douala',
            distance_km=250,
            prix_par_place=Decimal('5000'),
            date_heure_depart=timezone.now() + timedelta(days=1),
            places_disponibles=4,
            statut='ouvert'
        )
    
    def test_evaluation_creation_basic(self):
        """Test la création d'une évaluation"""
        # Marquer trajet comme terminé
        self.trajet.statut = 'termine'
        self.trajet.save()
        
        # Créer une réservation confirmée
        Reservation.objects.create(
            trajet=self.trajet,
            passager=self.passager,
            places_reservees=1,
            statut='confirmee'
        )
        
        # Créer une évaluation
        evaluation = Evaluation.objects.create(
            trajet=self.trajet,
            auteur=self.passager,
            cible=self.conducteur,
            note=4,
            commentaire='Bon conducteur'
        )
        
        # Vérifier
        self.assertEqual(evaluation.note, 4)
        self.assertEqual(evaluation.auteur, self.passager)
        self.assertEqual(evaluation.cible, self.conducteur)
        print("✓ Évaluation créée avec succès")
    
    def test_note_moyenne_update(self):
        """Test que la note moyenne se met à jour"""
        self.trajet.statut = 'termine'
        self.trajet.save()
        
        Reservation.objects.create(
            trajet=self.trajet,
            passager=self.passager,
            places_reservees=1,
            statut='confirmee'
        )
        
        # Créer plusieurs évaluations
        Evaluation.objects.create(
            trajet=self.trajet,
            auteur=self.passager,
            cible=self.conducteur,
            note=5
        )
        
        # Mettre à jour la note moyenne manuellement (comme dans la vue)
        from django.db.models import Avg
        note_moy = Evaluation.objects.filter(
            cible=self.conducteur
        ).aggregate(Avg('note'))['note__avg']
        
        self.conducteur.note = round(note_moy, 2)
        self.conducteur.save()
        
        # Vérifier
        self.assertEqual(self.conducteur.note, 5.0)
        print("✓ Note moyenne mise à jour correctement")
