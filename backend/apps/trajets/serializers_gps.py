from rest_framework import serializers
from ..modeles.models import PositionGPS


class PositionGPSSerializer(serializers.ModelSerializer):
    class Meta:
        model = PositionGPS
        fields = [
            'id', 'trajet', 'latitude', 'longitude', 'altitude', 
            'vitesse_kmh', 'direction', 'timestamp'
        ]
        read_only_fields = ['id', 'timestamp']


class PositionMiseAJourSerializer(serializers.Serializer):
    latitude = serializers.FloatField(required=True)
    longitude = serializers.FloatField(required=True)
    altitude = serializers.FloatField(required=False, allow_null=True)
    vitesse_kmh = serializers.FloatField(required=False, allow_null=True)
    direction = serializers.FloatField(required=False, allow_null=True)
    
    def validate_latitude(self, value):
        if not -90 <= value <= 90:
            raise serializers.ValidationError("La latitude doit être entre -90 et 90 degrés.")
        return value
    
    def validate_longitude(self, value):
        if not -180 <= value <= 180:
            raise serializers.ValidationError("La longitude doit être entre -180 et 180 degrés.")
        return value
    
    def validate_vitesse_kmh(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("La vitesse ne peut pas être négative.")
        return value
    
    def validate_direction(self, value):
        if value is not None and not 0 <= value < 360:
            raise serializers.ValidationError("La direction doit être entre 0 et 359 degrés.")
        return value
