from rest_framework import serializers
from ..modeles.models import Trajet


class TrajetSerializer(serializers.ModelSerializer):
    conducteur_nom = serializers.SerializerMethodField()
    conducteur_note = serializers.SerializerMethodField()
    places_restantes = serializers.SerializerMethodField()

    class Meta:
        model = Trajet
        fields = [
            'id', 'conducteur', 'conducteur_nom', 'conducteur_note',
            'depart', 'depart_lat', 'depart_lng',
            'destination', 'destination_lat', 'destination_lng',
            'escales',
            'distance_km', 'prix_par_place',
            'date_heure_depart', 'places_disponibles', 'places_restantes',
            'description', 'est_regulier', 'jours_semaine',
            'statut', 'created_at',
        ]
        read_only_fields = ['conducteur', 'created_at', 'updated_at']

    def get_conducteur_nom(self, obj):
        return f"{obj.conducteur.first_name} {obj.conducteur.last_name}".strip() or obj.conducteur.username

    def get_conducteur_note(self, obj):
        return obj.conducteur.note

    def get_places_restantes(self, obj):
        # places_disponibles - réservations confirmées
        reservations_confirmees = obj.reservations.filter(statut='confirmee').count()
        return obj.places_disponibles - reservations_confirmees


class TrajetCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trajet
        fields = [
            'depart', 'depart_lat', 'depart_lng',
            'destination', 'destination_lat', 'destination_lng',
            'escales',
            'distance_km', 'prix_par_place',
            'date_heure_depart', 'places_disponibles',
            'description', 'est_regulier', 'jours_semaine',
        ]

    def validate_places_disponibles(self, value):
        if value < 1:
            raise serializers.ValidationError("Il faut au moins 1 place.")
        if value > 8:
            raise serializers.ValidationError("Maximum 8 places.")
        return value

    def validate_distance_km(self, value):
        if value <= 0:
            raise serializers.ValidationError("La distance doit être positive.")
        return value

    def validate(self, attrs):
        # Vérifier que la date est dans le futur
        from django.utils import timezone
        if attrs.get('date_heure_depart') and attrs['date_heure_depart'] < timezone.now():
            raise serializers.ValidationError(
                {"date_heure_depart": "La date de départ doit être dans le futur."}
            )
        # Si trajet régulier, jours_semaine obligatoire
        if attrs.get('est_regulier') and not attrs.get('jours_semaine'):
            raise serializers.ValidationError(
                {"jours_semaine": "Sélectionnez au moins un jour pour un trajet régulier."}
            )
        return attrs

    def create(self, validated_data):
        # Le conducteur est injecté depuis la vue (request.user)
        validated_data['conducteur'] = self.context['request'].user
        return super().create(validated_data)