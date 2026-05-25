from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    Admin,
    Conducteur,
    Passager,
    Trajet,
    Reservation,
    Paiement,
    Evaluation,
    Message,
    Appel,
    Notification,
    Statistique,
    Plainte,
    Vehicule
)

Utilisateur = get_user_model()

# =====================================================
# UTILISATEUR
# =====================================================

class UtilisateurSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = Utilisateur
        fields = [
            'id',
            'username',
            'email',
            'role',
            'numero_telephone',
            'photo_profil',
            'note',
            'password'
        ]
        read_only_fields = ['id', 'note']

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = Utilisateur(**validated_data)
        user.set_password(password)
        user.save()
        return user


# =====================================================
# PROFILS
# =====================================================

class AdminSerializer(serializers.ModelSerializer):
    utilisateur = UtilisateurSerializer(read_only=True)

    class Meta:
        model = Admin
        fields = '__all__'


class ConducteurSerializer(serializers.ModelSerializer):
    utilisateur = UtilisateurSerializer(read_only=True)

    class Meta:
        model = Conducteur
        fields = '__all__'


class PassagerSerializer(serializers.ModelSerializer):
    utilisateur = UtilisateurSerializer(read_only=True)

    class Meta:
        model = Passager
        fields = '__all__'


# =====================================================
# VEHICULE
# =====================================================

class VehiculeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicule
        fields = '__all__'


# =====================================================
# TRAJET
# =====================================================

class TrajetSerializer(serializers.ModelSerializer):
    conducteur_details = UtilisateurSerializer(source='conducteur', read_only=True)

    class Meta:
        model = Trajet
        fields = '__all__'


# =====================================================
# RESERVATION
# =====================================================

class ReservationSerializer(serializers.ModelSerializer):
    trajet_details = TrajetSerializer(source='trajet', read_only=True)
    passager_details = UtilisateurSerializer(source='passager', read_only=True)

    class Meta:
        model = Reservation
        fields = '__all__'


# =====================================================
# PAIEMENT
# =====================================================

class PaiementSerializer(serializers.ModelSerializer):
    reservation_details = ReservationSerializer(source='reservation', read_only=True)

    class Meta:
        model = Paiement
        fields = '__all__'


# =====================================================
# EVALUATION
# =====================================================

class EvaluationSerializer(serializers.ModelSerializer):
    auteur_details = UtilisateurSerializer(source='auteur', read_only=True)
    cible_details = UtilisateurSerializer(source='cible', read_only=True)

    class Meta:
        model = Evaluation
        fields = '__all__'

    def validate_note(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("La note doit être entre 1 et 5.")
        return value


# =====================================================
# MESSAGE
# =====================================================

class MessageSerializer(serializers.ModelSerializer):
    expediteur_details = UtilisateurSerializer(source='expediteur', read_only=True)
    destinataire_details = UtilisateurSerializer(source='destinataire', read_only=True)

    class Meta:
        model = Message
        fields = '__all__'


# =====================================================
# APPEL
# =====================================================

class AppelSerializer(serializers.ModelSerializer):
    appelant_details = UtilisateurSerializer(source='appelant', read_only=True)
    destinataire_details = UtilisateurSerializer(source='destinataire', read_only=True)

    class Meta:
        model = Appel
        fields = '__all__'


# =====================================================
# NOTIFICATION
# =====================================================

class NotificationSerializer(serializers.ModelSerializer):

    class Meta:
        model = Notification
        fields = '__all__'


# =====================================================
# STATISTIQUE
# =====================================================

class StatistiqueSerializer(serializers.ModelSerializer):
    trajet_details = TrajetSerializer(source='trajet', read_only=True)

    class Meta:
        model = Statistique
        fields = '__all__'


# =====================================================
# ÉCONOMIE PASSAGER
# =====================================================

from .utils import calculer_economie_passager


class EconomieTrajetSerializer(serializers.Serializer):
    """
    Serializer pour les calculs économiques d'un trajet
    """
    distance_km = serializers.FloatField()
    type_vehicule = serializers.ChoiceField(choices=[
        ('moto', 'Moto'),
        ('voiture', 'Voiture'),
        ('minibus', 'Minibus'),
        ('camion', 'Camion')
    ])
    prix_kovoit_place = serializers.DecimalField(max_digits=10, decimal_places=2)
    
    # Champs calculés en lecture seule
    prix_reference = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    economie = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    pourcentage_economie = serializers.DecimalField(max_digits=5, decimal_places=2, read_only=True)
    reference_type = serializers.CharField(read_only=True)


class ReservationEconomieSerializer(serializers.ModelSerializer):
    """
    Serializer pour les réservations avec calculs économiques
    """
    trajet_info = serializers.SerializerMethodField()
    economie_totale = serializers.SerializerMethodField()
    pourcentage_economie = serializers.SerializerMethodField()
    prix_reference_total = serializers.SerializerMethodField()
    reference_type = serializers.SerializerMethodField()
    
    class Meta:
        model = Reservation
        fields = [
            'id', 'trajet', 'trajet_info', 'passager', 'places_reservees',
            'statut', 'date_reservation', 'economie_totale',
            'pourcentage_economie', 'prix_reference_total', 'reference_type'
        ]
        read_only_fields = ['passager', 'date_reservation']
    
    def get_trajet_info(self, obj):
        trajet = obj.trajet
        return {
            'id': trajet.id,
            'depart': trajet.depart,
            'destination': trajet.destination,
            'distance_km': trajet.distance_km,
            'prix_par_place': trajet.prix_par_place,
            'date_heure_depart': trajet.date_heure_depart,
            'conducteur_nom': f"{trajet.conducteur.first_name} {trajet.conducteur.last_name}".strip() or trajet.conducteur.username,
        }
    
    def get_economie_totale(self, obj):
        if obj.statut != 'confirmee' or not obj.trajet.distance_km:
            return 0
        
        type_vehicule = obj.trajet.vehicule.type_vehicule if obj.trajet.vehicule else 'voiture'
        calc = calculer_economie_passager(
            obj.trajet.distance_km,
            type_vehicule,
            float(obj.trajet.prix_par_place)
        )
        return round(calc['economie'] * obj.places_reservees, 2)
    
    def get_pourcentage_economie(self, obj):
        if obj.statut != 'confirmee' or not obj.trajet.distance_km:
            return 0
        
        type_vehicule = obj.trajet.vehicule.type_vehicule if obj.trajet.vehicule else 'voiture'
        calc = calculer_economie_passager(
            obj.trajet.distance_km,
            type_vehicule,
            float(obj.trajet.prix_par_place)
        )
        return round(calc['pourcentage_economie'], 2)
    
    def get_prix_reference_total(self, obj):
        if obj.statut != 'confirmee' or not obj.trajet.distance_km:
            return 0
        
        type_vehicule = obj.trajet.vehicule.type_vehicule if obj.trajet.vehicule else 'voiture'
        calc = calculer_economie_passager(
            obj.trajet.distance_km,
            type_vehicule,
            float(obj.trajet.prix_par_place)
        )
        return round(calc['prix_reference'] * obj.places_reservees, 2)
    
    def get_reference_type(self, obj):
        if not obj.trajet.distance_km:
            return 'N/A'
        
        type_vehicule = obj.trajet.vehicule.type_vehicule if obj.trajet.vehicule else 'voiture'
        return 'Gozem' if type_vehicule == 'moto' else 'Taxi'


class StatistiquesEconomieSerializer(serializers.Serializer):
    """
    Serializer pour les statistiques économiques du passager
    """
    periode = serializers.CharField()
    total_economie = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_depense_kovoit = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_depense_reference = serializers.DecimalField(max_digits=12, decimal_places=2)
    nombre_reservations = serializers.IntegerField()
    economie_moyenne_reservation = serializers.DecimalField(max_digits=10, decimal_places=2)
    details_reservations = serializers.ListField(child=serializers.DictField(), required=False)


class ComparaisonTypeVehiculeSerializer(serializers.Serializer):
    """
    Serializer pour la comparaison d'économies par type de véhicule
    """
    periode = serializers.CharField()
    stats_par_type = serializers.DictField()
    total_general = serializers.DictField()


class EconomieAnnuelleSerializer(serializers.Serializer):
    """
    Serializer pour les économies annuelles
    """
    periode = serializers.CharField()
    total_economie = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_depense_kovoit = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_depense_reference = serializers.DecimalField(max_digits=12, decimal_places=2)
    nombre_reservations = serializers.IntegerField()
    economie_moyenne_reservation = serializers.DecimalField(max_digits=10, decimal_places=2)
    details_reservations = serializers.ListField(child=serializers.DictField(), required=False)


# =====================================================
# ADMINISTRATION - PLAINTE
# =====================================================

class PlainteSerializer(serializers.ModelSerializer):
    signalataire_details = UtilisateurSerializer(source='signalataire', read_only=True)
    utilisateur_signale_details = UtilisateurSerializer(source='utilisateur_signale', read_only=True)
    admin_assigne_details = UtilisateurSerializer(source='admin_assigne', read_only=True)

    class Meta:
        model = Plainte
        fields = '__all__'


# =====================================================
# ADMINISTRATION - STATISTIQUES GLOBALES
# =====================================================

class StatistiquesGlobalesSerializer(serializers.Serializer):
    """
    Statistiques générales pour l'admin
    """
    nombre_utilisateurs_total = serializers.IntegerField()
    nombre_conducteurs = serializers.IntegerField()
    nombre_passagers = serializers.IntegerField()
    nombre_admins = serializers.IntegerField()
    
    nombre_trajets_total = serializers.IntegerField()
    nombre_trajets_ouverts = serializers.IntegerField()
    nombre_trajets_termines = serializers.IntegerField()
    nombre_trajets_annules = serializers.IntegerField()
    
    nombre_reservations_total = serializers.IntegerField()
    nombre_reservations_confirmees = serializers.IntegerField()
    nombre_reservations_terminees = serializers.IntegerField()
    
    nombre_paiements_total = serializers.IntegerField()
    nombre_paiements_confirmes = serializers.IntegerField()
    
    revenu_total_kovoit = serializers.DecimalField(max_digits=15, decimal_places=2)
    revenu_total_conducteurs = serializers.DecimalField(max_digits=15, decimal_places=2)
    
    nombre_evaluations = serializers.IntegerField()
    note_moyenne_conducteurs = serializers.FloatField()
    note_moyenne_passagers = serializers.FloatField()
    
    nombre_plaintes = serializers.IntegerField()
    nombre_plaintes_en_attente = serializers.IntegerField()
    nombre_plaintes_resolues = serializers.IntegerField()


# =====================================================
# ADMINISTRATION - UTILISATEUR DETAIL
# =====================================================

class UtilisateurDetailAdminSerializer(serializers.ModelSerializer):
    profil_conducteur = ConducteurSerializer(source='profil_conducteur', read_only=True)
    profil_passager = PassagerSerializer(source='profil_passager', read_only=True)
    vehicules = serializers.SerializerMethodField()
    nombre_trajets = serializers.SerializerMethodField()
    nombre_reservations = serializers.SerializerMethodField()
    nombre_evaluations_recues = serializers.SerializerMethodField()
    nombre_plaintes = serializers.SerializerMethodField()

    class Meta:
        model = Utilisateur
        fields = [
            'id', 'username', 'email', 'role', 'numero_telephone',
            'photo_profil', 'note', 'is_active', 'date_joined',
            'profil_conducteur', 'profil_passager', 'vehicules',
            'nombre_trajets', 'nombre_reservations',
            'nombre_evaluations_recues', 'nombre_plaintes'
        ]
        read_only_fields = [
            'id', 'date_joined', 'nombre_trajets',
            'nombre_reservations', 'nombre_evaluations_recues', 'nombre_plaintes'
        ]

    def get_vehicules(self, obj):
        from ..modeles.models import Vehicule
        if hasattr(obj, 'profil_conducteur'):
            vehicules = obj.profil_conducteur.vehicules.all()
            return VehiculeSerializer(vehicules, many=True).data
        return []

    def get_nombre_trajets(self, obj):
        return obj.trajets.count() if hasattr(obj, 'trajets') else 0

    def get_nombre_reservations(self, obj):
        return obj.reservations.count() if hasattr(obj, 'reservations') else 0

    def get_nombre_evaluations_recues(self, obj):
        return obj.evaluations_recues.count() if hasattr(obj, 'evaluations_recues') else 0

    def get_nombre_plaintes(self, obj):
        return obj.plaintes_recues.count() if hasattr(obj, 'plaintes_recues') else 0


# =====================================================
# ADMINISTRATION - TRAJET DETAIL
# =====================================================

class TrajetDetailAdminSerializer(serializers.ModelSerializer):
    conducteur_details = UtilisateurSerializer(source='conducteur', read_only=True)
    reservations_count = serializers.SerializerMethodField()
    revenus_total = serializers.SerializerMethodField()
    commission_kovoit = serializers.SerializerMethodField()

    class Meta:
        model = Trajet
        fields = [
            'id', 'conducteur', 'conducteur_details', 'vehicule',
            'depart', 'destination', 'distance_km', 'cout_total',
            'prix_par_place', 'date_heure_depart', 'places_disponibles',
            'statut', 'est_regulier', 'created_at', 'updated_at',
            'reservations_count', 'revenus_total', 'commission_kovoit'
        ]

    def get_reservations_count(self, obj):
        return obj.reservations.count()

    def get_revenus_total(self, obj):
        total = 0
        for res in obj.reservations.filter(statut__in=['confirmee', 'terminee']):
            if hasattr(res, 'paiement') and res.paiement.statut in ['CONFIRME', 'PAYEE']:
                total += float(res.paiement.montant)
        return total

    def get_commission_kovoit(self, obj):
        return self.get_revenus_total(obj) * 0.10


# =====================================================
# ADMINISTRATION - PAIEMENT DETAIL
# =====================================================

class PaiementDetailAdminSerializer(serializers.ModelSerializer):
    passager_details = UtilisateurSerializer(source='passager', read_only=True)
    conducteur_details = UtilisateurSerializer(source='conducteur', read_only=True)
    trajet_details = TrajetSerializer(source='reservation.trajet', read_only=True)

    class Meta:
        model = Paiement
        fields = [
            'id', 'reservation', 'passager', 'passager_details',
            'conducteur', 'conducteur_details', 'montant',
            'moyen_paiement', 'statut', 'date_creation',
            'date_confirmation', 'date_payement', 'trajet_details'
        ]