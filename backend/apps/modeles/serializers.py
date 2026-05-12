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
    Statistique
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