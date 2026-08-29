"""
Tests unitaires pour les paiements en espèces et les statistiques
"""
from django.test import TestCase, TransactionTestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from decimal import Decimal
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

from apps.modeles.models import (
    Utilisateur, Trajet, Reservation, Paiement, Vehicule, Conducteur, Wallet, DepotWallet
)
from apps.statistiques.services import actualiser_statistiques_economie
from apps.paiements import wallet_service, payplus_service as payplus

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


class WalletTestCase(TransactionTestCase):
    """Tests du wallet conducteur : crédit électronique, dette espèces, dépôt, retrait."""

    def setUp(self):
        self.conducteur = Utilisateur.objects.create_user(
            username='wconducteur', email='wconducteur@test.com',
            password='pass123', role='conducteur',
        )
        Conducteur.objects.create(utilisateur=self.conducteur, numero_permis='CM999', experience_annees=3)
        self.passager = Utilisateur.objects.create_user(
            username='wpassager', email='wpassager@test.com',
            password='pass123', role='passager',
        )
        self.trajet = Trajet.objects.create(
            conducteur=self.conducteur,
            depart='Lomé', destination='Kpalimé',
            depart_lat=6.13, depart_lng=1.22,
            destination_lat=6.90, destination_lng=0.63,
            distance_km=120, prix_par_place=Decimal('1000'),
            date_heure_depart=timezone.now() + timedelta(days=1),
            places_disponibles=4, statut='ouvert',
        )

    def _reservation_payee(self, moyen, statut, montant=Decimal('1000')):
        reservation = Reservation.objects.create(
            trajet=self.trajet, passager=self.passager,
            places_reservees=1, statut='confirmee',
        )
        return Paiement.objects.create(
            reservation=reservation, passager=self.passager, conducteur=self.conducteur,
            montant=montant, moyen_paiement=moyen, statut=statut,
            date_confirmation=timezone.now(),
        )

    def test_paiement_electronique_credite_wallet_conducteur_et_plateforme(self):
        paiement = self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)

        wallet_conducteur = Wallet.pour(self.conducteur)
        wallet_plateforme = Wallet.plateforme()

        # 10% commission (défaut) : net 900, commission 100
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('900'))
        self.assertEqual(wallet_conducteur.solde_du, Decimal('0'))
        self.assertEqual(wallet_plateforme.solde_disponible, Decimal('100'))

    def test_paiement_especes_cree_une_dette_sans_crediter_le_disponible(self):
        self._reservation_payee('ESPECE', Paiement.Statut.CONFIRME)

        wallet_conducteur = Wallet.pour(self.conducteur)
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('0'))
        self.assertEqual(wallet_conducteur.solde_du, Decimal('100'))

    def test_signal_est_idempotent_meme_paiement_resauvegarde_plusieurs_fois(self):
        paiement = self._reservation_payee('ESPECE', Paiement.Statut.CONFIRME)
        # Resauvegarder plusieurs fois ne doit pas recréer la dette à chaque fois.
        paiement.save()
        paiement.save()

        wallet_conducteur = Wallet.pour(self.conducteur)
        self.assertEqual(wallet_conducteur.solde_du, Decimal('100'))

    def test_depot_regle_la_dette_avant_de_crediter_le_disponible(self):
        self._reservation_payee('ESPECE', Paiement.Statut.CONFIRME)  # dette 100
        wallet_conducteur = Wallet.pour(self.conducteur)

        wallet_service.deposer(
            wallet=wallet_conducteur, montant=Decimal('1000'),
            reference='TEST-DEPOT-1',
        )

        wallet_conducteur.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_du, Decimal('0'))
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('900'))

    def test_retrait_bloque_si_dette_en_cours(self):
        self._reservation_payee('ESPECE', Paiement.Statut.CONFIRME)  # dette 100
        wallet_conducteur = Wallet.pour(self.conducteur)
        wallet_conducteur.solde_disponible = Decimal('500')
        wallet_conducteur.save()

        with self.assertRaises(wallet_service.DetteEnCoursError):
            wallet_service.demander_retrait(
                wallet=wallet_conducteur, montant=Decimal('100'),
                moyen='FLOOZ', numero_destination='90000000',
            )

    def test_retrait_debite_immediatement_et_echec_rembourse(self):
        self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)  # crédite 900 disponible
        wallet_conducteur = Wallet.pour(self.conducteur)

        retrait = wallet_service.demander_retrait(
            wallet=wallet_conducteur, montant=Decimal('900'),
            moyen='FLOOZ', numero_destination='90000000',
        )
        wallet_conducteur.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('0'))

        wallet_service.echouer_retrait(retrait=retrait, motif='Numéro invalide')
        wallet_conducteur.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('900'))

    def test_retrait_leve_erreur_si_solde_insuffisant(self):
        wallet_conducteur = Wallet.pour(self.conducteur)
        with self.assertRaises(wallet_service.SoldeInsuffisantError):
            wallet_service.demander_retrait(
                wallet=wallet_conducteur, montant=Decimal('100'),
                moyen='FLOOZ', numero_destination='90000000',
            )

    def test_annulation_sans_penalite_reprend_tout_le_credit(self):
        paiement = self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)  # net 900, commission 100
        wallet_conducteur = Wallet.pour(self.conducteur)
        wallet_plateforme = Wallet.plateforme()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('900'))

        resultat = wallet_service.annuler_paiement_electronique(paiement, penalite=Decimal('0'))

        wallet_conducteur.refresh_from_db()
        wallet_plateforme.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('0'))
        self.assertEqual(wallet_conducteur.solde_du, Decimal('0'))
        self.assertEqual(wallet_plateforme.solde_disponible, Decimal('0'))
        self.assertEqual(resultat['a_rembourser_passager'], Decimal('1000'))

        paiement.refresh_from_db()
        self.assertEqual(paiement.statut, Paiement.Statut.REMBOURSE)

    def test_annulation_avec_penalite_laisse_la_penalite_au_conducteur(self):
        paiement = self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)  # net 900
        wallet_conducteur = Wallet.pour(self.conducteur)

        resultat = wallet_service.annuler_paiement_electronique(paiement, penalite=Decimal('200'))

        wallet_conducteur.refresh_from_db()
        # 900 repris intégralement, puis 200 de pénalité recréditée en compensation.
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('200'))
        self.assertEqual(resultat['penalite_conducteur'], Decimal('200'))
        self.assertEqual(resultat['a_rembourser_passager'], Decimal('800'))

    def test_annulation_apres_retrait_cree_une_dette_au_lieu_de_bloquer(self):
        paiement = self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)  # net 900 crédité
        wallet_conducteur = Wallet.pour(self.conducteur)
        # Le conducteur retire tout avant l'annulation : plus rien de disponible.
        wallet_service.demander_retrait(
            wallet=wallet_conducteur, montant=Decimal('900'),
            moyen='FLOOZ', numero_destination='90000000',
        )
        wallet_conducteur.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('0'))

        # L'annulation ne doit jamais lever d'exception, même sans fonds disponibles.
        wallet_service.annuler_paiement_electronique(paiement, penalite=Decimal('0'))

        wallet_conducteur.refresh_from_db()
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('0'))
        self.assertEqual(wallet_conducteur.solde_du, Decimal('900'))

    def test_annulation_est_idempotente(self):
        paiement = self._reservation_payee('FLOOZ', Paiement.Statut.PAYEE)
        wallet_service.annuler_paiement_electronique(paiement, penalite=Decimal('0'))
        # Rejouer ne doit rien reprendre une seconde fois (paiement déjà REMBOURSE).
        resultat_2 = wallet_service.annuler_paiement_electronique(paiement, penalite=Decimal('0'))
        self.assertIsNone(resultat_2)


def _mock_resp(json_data, status_code=200):
    m = MagicMock()
    m.status_code = status_code
    m.json.return_value = json_data
    return m


def _mock_resp_non_json(status_code=404, text='<html>404</html>'):
    m = MagicMock()
    m.status_code = status_code
    m.text = text
    m.json.side_effect = ValueError('Expecting value: line 2 column 1 (char 1)')
    return m


class PayPlusServiceTestCase(TestCase):
    """Tests unitaires de payplus_service.py — aucun appel réseau réel (requests mocké)."""

    @patch('apps.paiements.payplus_service.requests.post')
    def test_creer_facture_succes(self, mock_post):
        mock_post.return_value = _mock_resp({
            'response_code': '00', 'token': 'TOK123', 'response_text': 'https://app.payplus.africa/pay/xyz',
        })
        result = payplus.creer_facture(
            phone='90000000', amount=1000, description='Test', transref='KOVOIT-1-abc',
            notify_url='https://x/webhook/', return_url='https://x/return', cancel_url='https://x/cancel',
            website_url='https://x',
        )
        self.assertEqual(result['token'], 'TOK123')
        self.assertEqual(result['payment_url'], 'https://app.payplus.africa/pay/xyz')
        # Vérifie les en-têtes envoyés (Apikey + Authorization: Bearer)
        _, kwargs = mock_post.call_args
        self.assertIn('Apikey', kwargs['headers'])
        self.assertTrue(kwargs['headers']['Authorization'].startswith('Bearer '))
        self.assertEqual(kwargs['json']['commande']['invoice']['customer'], '22890000000')

    @patch('apps.paiements.payplus_service.requests.post')
    def test_creer_facture_reponse_non_json_leve_erreur_claire(self, mock_post):
        mock_post.return_value = _mock_resp_non_json(status_code=404, text='<html>404</html>')
        with self.assertRaises(payplus.PayPlusError) as ctx:
            payplus.creer_facture(
                phone='90000000', amount=1000, description='Test', transref='KOVOIT-1-abc',
                notify_url='https://x/webhook/', return_url='https://x/return', cancel_url='https://x/cancel',
                website_url='https://x',
            )
        self.assertIn('404', str(ctx.exception))
        self.assertEqual(ctx.exception.code, 'INVALID_RESPONSE')

    @patch('apps.paiements.payplus_service.requests.post')
    def test_creer_facture_response_code_echec(self, mock_post):
        mock_post.return_value = _mock_resp({'response_code': '01', 'response_text': 'Solde marchand insuffisant'})
        with self.assertRaises(payplus.PayPlusError) as ctx:
            payplus.creer_facture(
                phone='90000000', amount=1000, description='Test', transref='KOVOIT-1-abc',
                notify_url='https://x/webhook/', return_url='https://x/return', cancel_url='https://x/cancel',
                website_url='https://x',
            )
        self.assertIn('Solde marchand insuffisant', str(ctx.exception))

    @patch('apps.paiements.payplus_service.requests.post')
    def test_verifier_facture_completed(self, mock_post):
        mock_post.return_value = _mock_resp({'response_code': '00', 'description': 'completed'})
        result = payplus.verifier_facture('TOK123')
        self.assertEqual(result['statut'], 'completed')

    @patch('apps.paiements.payplus_service.requests.post')
    def test_verifier_facture_pending(self, mock_post):
        mock_post.return_value = _mock_resp({'response_code': '00', 'description': 'pending'})
        result = payplus.verifier_facture('TOK123')
        self.assertEqual(result['statut'], 'pending')

    def test_normaliser_telephone_togo(self):
        self.assertEqual(payplus.normaliser_telephone_togo('90000000'), '22890000000')
        self.assertEqual(payplus.normaliser_telephone_togo('228 90 00 00 00'), '22890000000')
        self.assertEqual(payplus.normaliser_telephone_togo('+22890000000'), '22890000000')


class PaiementElectroniqueViewTestCase(TransactionTestCase):
    """Tests des vues PaiementViewSet.initier/verifier/webhook avec PayPlus mocké."""

    def setUp(self):
        from rest_framework.test import APIRequestFactory
        self.factory = APIRequestFactory()

        self.conducteur = Utilisateur.objects.create_user(
            username='pv_conducteur', email='pvc@test.com', password='pass123', role='conducteur',
        )
        Conducteur.objects.create(utilisateur=self.conducteur, numero_permis='PV1', experience_annees=1)
        self.passager = Utilisateur.objects.create_user(
            username='pv_passager', email='pvp@test.com', password='pass123', role='passager',
        )
        self.trajet = Trajet.objects.create(
            conducteur=self.conducteur, depart='Lomé', destination='Kpalimé',
            depart_lat=6.13, depart_lng=1.22, destination_lat=6.90, destination_lng=0.63,
            distance_km=120, prix_par_place=Decimal('1000'),
            date_heure_depart=timezone.now() + timedelta(days=1),
            places_disponibles=4, statut='ouvert',
        )
        self.reservation = Reservation.objects.create(
            trajet=self.trajet, passager=self.passager, places_reservees=1, statut='confirmee',
        )

    def _auth(self, req, user):
        from rest_framework.test import force_authenticate
        force_authenticate(req, user=user)
        return req

    @patch('apps.paiements.views.payplus.creer_facture')
    def test_initier_cree_paiement_en_attente_avec_payment_url(self, mock_creer):
        from apps.paiements.views import PaiementViewSet
        mock_creer.return_value = {'token': 'TOK1', 'payment_url': 'https://pay/xyz', 'response_code': '00'}

        req = self.factory.post('/api/paiements/initier/', {
            'reservation_id': self.reservation.id, 'phone_number': '90000000', 'network': 'FLOOZ',
        }, format='json')
        self._auth(req, self.passager)
        resp = PaiementViewSet.as_view({'post': 'initier'})(req)

        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data['payment_url'], 'https://pay/xyz')
        paiement = Paiement.objects.get(reservation=self.reservation)
        self.assertEqual(paiement.statut, Paiement.Statut.EN_ATTENTE)
        self.assertEqual(paiement.reference_mobile, 'TOK1')

    @patch('apps.paiements.views.payplus.verifier_facture')
    @patch('apps.paiements.views.payplus.creer_facture')
    def test_verifier_completed_confirme_paiement_et_credite_wallet(self, mock_creer, mock_verif):
        from apps.paiements.views import PaiementViewSet
        mock_creer.return_value = {'token': 'TOK2', 'payment_url': 'https://pay/xyz', 'response_code': '00'}

        req = self.factory.post('/api/paiements/initier/', {
            'reservation_id': self.reservation.id, 'phone_number': '90000000', 'network': 'FLOOZ',
        }, format='json')
        self._auth(req, self.passager)
        PaiementViewSet.as_view({'post': 'initier'})(req)

        mock_verif.return_value = {'statut': 'completed', 'response_code': '00', 'raw': {}}
        req2 = self.factory.post('/api/paiements/verifier/', {'token': 'TOK2'}, format='json')
        self._auth(req2, self.passager)
        resp2 = PaiementViewSet.as_view({'post': 'verifier'})(req2)

        self.assertEqual(resp2.status_code, 200)
        self.assertEqual(resp2.data['statut'], 'payee')

        paiement = Paiement.objects.get(reservation=self.reservation)
        self.assertEqual(paiement.statut, Paiement.Statut.PAYEE)

        wallet_conducteur = Wallet.pour(self.conducteur)
        self.assertEqual(wallet_conducteur.solde_disponible, Decimal('900'))  # 1000 - 10%

    @patch('apps.paiements.views.payplus.verifier_facture')
    @patch('apps.paiements.views.payplus.creer_facture')
    def test_webhook_utilise_transref_de_la_query_string_pas_le_corps(self, mock_creer, mock_verif):
        """Le webhook ne doit jamais faire confiance au corps — seulement au transref qu'on a nous-mêmes fourni."""
        from apps.paiements.views import PaiementViewSet
        mock_creer.return_value = {'token': 'TOK3', 'payment_url': 'https://pay/xyz', 'response_code': '00'}

        req = self.factory.post('/api/paiements/initier/', {
            'reservation_id': self.reservation.id, 'phone_number': '90000000', 'network': 'FLOOZ',
        }, format='json')
        self._auth(req, self.passager)
        PaiementViewSet.as_view({'post': 'initier'})(req)

        mock_verif.return_value = {'statut': 'completed', 'response_code': '00', 'raw': {}}
        # Passe par le vrai routage (Client Django) plutôt que d'appeler la vue
        # directement : c'est le routeur qui applique permission_classes=[]
        # déclaré sur @action, un appel manuel à as_view() le perdrait.
        resp = self.client.post(
            f'/api/paiements/webhook/?transref=KOVOIT-{self.reservation.id}-XYZ',
            {'un_champ_quelconque': 'valeur_non_fiable'},
        )

        self.assertEqual(resp.status_code, 200)
        paiement = Paiement.objects.get(reservation=self.reservation)
        self.assertEqual(paiement.statut, Paiement.Statut.PAYEE)


class DepotWebViewTestCase(TransactionTestCase):
    """Tests de WalletViewSet.deposer_initier/deposer_verifier avec PayPlus mocké."""

    def setUp(self):
        from rest_framework.test import APIRequestFactory
        self.factory = APIRequestFactory()
        self.conducteur = Utilisateur.objects.create_user(
            username='dv_conducteur', email='dvc@test.com', password='pass123', role='conducteur',
        )
        Conducteur.objects.create(utilisateur=self.conducteur, numero_permis='DV1', experience_annees=1)

    def _auth(self, req):
        from rest_framework.test import force_authenticate
        force_authenticate(req, user=self.conducteur)
        return req

    @patch('apps.paiements.views.payplus.creer_facture')
    def test_deposer_initier_cree_depot_en_attente(self, mock_creer):
        from apps.paiements.views import WalletViewSet
        mock_creer.return_value = {'token': 'DTOK1', 'payment_url': 'https://pay/depot', 'response_code': '00'}

        req = self.factory.post('/api/paiements/wallet/deposer_initier/', {
            'montant': '5000', 'phone_number': '90000000', 'network': 'FLOOZ',
        }, format='json')
        self._auth(req)
        resp = WalletViewSet.as_view({'post': 'deposer_initier'})(req)

        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data['payment_url'], 'https://pay/depot')
        depot = DepotWallet.objects.get(token='DTOK1')
        self.assertEqual(depot.montant, Decimal('5000'))
        self.assertEqual(depot.statut, DepotWallet.Statut.EN_ATTENTE)

    @patch('apps.paiements.views.payplus.verifier_facture')
    @patch('apps.paiements.views.payplus.creer_facture')
    def test_deposer_verifier_credite_une_seule_fois_meme_appele_deux_fois(self, mock_creer, mock_verif):
        from apps.paiements.views import WalletViewSet
        mock_creer.return_value = {'token': 'DTOK2', 'payment_url': 'https://pay/depot', 'response_code': '00'}

        req = self.factory.post('/api/paiements/wallet/deposer_initier/', {
            'montant': '5000', 'phone_number': '90000000', 'network': 'FLOOZ',
        }, format='json')
        self._auth(req)
        init_resp = WalletViewSet.as_view({'post': 'deposer_initier'})(req)
        transref = init_resp.data['transref']

        mock_verif.return_value = {'statut': 'completed', 'response_code': '00', 'raw': {}}

        req2 = self.factory.post('/api/paiements/wallet/deposer_verifier/', {
            'token': 'DTOK2', 'transref': transref,
        }, format='json')
        self._auth(req2)
        resp2 = WalletViewSet.as_view({'post': 'deposer_verifier'})(req2)
        self.assertEqual(resp2.status_code, 200)
        self.assertEqual(resp2.data['statut'], 'confirme')
        self.assertEqual(resp2.data['solde_disponible'], 5000.0)

        # Deuxième appel (ex: client qui re-vérifie) : ne doit pas créditer deux fois.
        req3 = self.factory.post('/api/paiements/wallet/deposer_verifier/', {
            'token': 'DTOK2', 'transref': transref,
        }, format='json')
        self._auth(req3)
        resp3 = WalletViewSet.as_view({'post': 'deposer_verifier'})(req3)
        self.assertEqual(resp3.status_code, 200)

        wallet = Wallet.pour(self.conducteur)
        self.assertEqual(wallet.solde_disponible, Decimal('5000'))
