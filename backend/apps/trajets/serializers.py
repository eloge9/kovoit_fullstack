from rest_framework import serializers
from django.utils import timezone
from ..modeles.models import Trajet, Vehicule


class TrajetSerializer(serializers.ModelSerializer):
    conducteur_nom   = serializers.SerializerMethodField()
    conducteur_note  = serializers.SerializerMethodField()
    conducteur_id    = serializers.SerializerMethodField()
    places_restantes = serializers.SerializerMethodField()
    type_vehicule    = serializers.SerializerMethodField()
    vehicule_info    = serializers.SerializerMethodField()

    class Meta:
        model  = Trajet
        fields = [
            'id', 'conducteur', 'conducteur_id', 'conducteur_nom', 'conducteur_note',
            'vehicule', 'vehicule_info', 'type_vehicule',
            'depart', 'depart_lat', 'depart_lng',
            'destination', 'destination_lat', 'destination_lng',
            'distance_km', 'cout_total', 'prix_par_place',
            'date_heure_depart', 'places_disponibles', 'places_restantes',
            'description', 'est_regulier', 'jours_semaine',
            'polyline', 'polyline_stored', 'tolerance_detour_km',
            'statut', 'created_at',
        ]
        read_only_fields = ['conducteur', 'created_at', 'updated_at']

    def get_conducteur_id(self, obj):
        return str(obj.conducteur.id)

    def get_conducteur_nom(self, obj):
        return f"{obj.conducteur.first_name} {obj.conducteur.last_name}".strip() or obj.conducteur.username

    def get_conducteur_note(self, obj):
        return obj.conducteur.note

    def get_places_restantes(self, obj):
        from django.db.models import Sum
        places_prises = obj.reservations.filter(statut='confirmee').aggregate(
            total=Sum('places_reservees')
        )['total'] or 0
        return max(0, obj.places_disponibles - places_prises)

    def get_type_vehicule(self, obj):
        return obj.vehicule.type_vehicule if obj.vehicule else None

    def get_vehicule_info(self, obj):
        if obj.vehicule:
            return {
                "id":            obj.vehicule.id,
                "type_vehicule": obj.vehicule.type_vehicule,
                "marque":        obj.vehicule.marque,
                "modele":        obj.vehicule.modele,
                "couleur":       obj.vehicule.couleur,
                "plaque":        obj.vehicule.plaque,
                "places_max":    obj.vehicule.places_max,
            }
        return None


class TrajetCreateSerializer(serializers.ModelSerializer):
    vehicule_id = serializers.IntegerField(write_only=True)

    class Meta:
        model  = Trajet
        fields = [
            'vehicule_id',
            'depart', 'depart_lat', 'depart_lng',
            'destination', 'destination_lat', 'destination_lng',
            'distance_km',
            'date_heure_depart', 'places_disponibles',
            'description', 'est_regulier', 'jours_semaine',
        ]

    def validate_vehicule_id(self, value):
        try:
            vehicule = Vehicule.objects.get(pk=value)
        except Vehicule.DoesNotExist:
            raise serializers.ValidationError("Véhicule introuvable.")
        request = self.context.get('request')
        if request and vehicule.conducteur.utilisateur != request.user:
            raise serializers.ValidationError("Ce véhicule ne vous appartient pas.")
        if not vehicule.est_actif:
            raise serializers.ValidationError("Ce véhicule est désactivé.")
        return value

    def validate_places_disponibles(self, value):
        if value < 1:
            raise serializers.ValidationError("Il faut au moins 1 place.")
        return value

    def validate(self, attrs):
        vehicule_id = attrs.get('vehicule_id')
        places      = attrs.get('places_disponibles')
        if vehicule_id and places:
            try:
                vehicule = Vehicule.objects.get(pk=vehicule_id)
                if places > vehicule.places_max:
                    raise serializers.ValidationError({
                        "places_disponibles": f"Maximum {vehicule.places_max} place(s) pour ce véhicule."
                    })
            except Vehicule.DoesNotExist:
                pass

        # Valider la date seulement à la création (instance=None)
        if not self.instance and attrs.get('date_heure_depart') and attrs['date_heure_depart'] < timezone.now():
            raise serializers.ValidationError(
                {"date_heure_depart": "La date de départ doit être dans le futur."}
            )

        if attrs.get('est_regulier') and not attrs.get('jours_semaine'):
            raise serializers.ValidationError(
                {"jours_semaine": "Sélectionnez au moins un jour pour un trajet régulier."}
            )
        return attrs

    def create(self, validated_data):
        vehicule_id = validated_data.pop('vehicule_id')
        vehicule    = Vehicule.objects.get(pk=vehicule_id)
        validated_data['conducteur'] = self.context['request'].user
        validated_data['vehicule']   = vehicule

        # Calculer le prix AVANT create pour satisfaire la contrainte NOT NULL
        try:
            from .tarification import calculer_prix, type_vehicule_str, capacite_vehicule
            tarif = calculer_prix(
                float(validated_data.get('distance_km') or 0),
                type_vehicule_str(vehicule),
                capacite_vehicule(vehicule),
            )
            validated_data['prix_par_place'] = tarif['prix_par_place']
            validated_data['cout_total']     = tarif['cout_total']
        except Exception:
            validated_data.setdefault('prix_par_place', 0)
            validated_data.setdefault('cout_total', 0)

        trajet = super().create(validated_data)

        # Store OSRM polyline (non-blocking)
        try:
            from .matching import fetch_and_store_polyline
            if trajet.depart_lat and trajet.destination_lat:
                fetch_and_store_polyline(trajet)
        except Exception:
            pass
        return trajet