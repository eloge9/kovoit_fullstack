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