from rest_framework import serializers
from ..modeles.models import Reservation


class ReservationSerializer(serializers.ModelSerializer):
    """Lecture — utilisé pour afficher les réservations."""

    # Infos trajet
    depart      = serializers.CharField(source='trajet.depart', read_only=True)
    destination = serializers.CharField(source='trajet.destination', read_only=True)
    date_depart = serializers.DateTimeField(source='trajet.date_heure_depart', read_only=True)
    prix_par_place = serializers.DecimalField(
        source='trajet.prix_par_place',
        max_digits=10, decimal_places=2,
        read_only=True
    )

    # Infos conducteur
    conducteur = serializers.SerializerMethodField()
    conducteur_note = serializers.SerializerMethodField()

    # Infos passager (pour le conducteur)
    passager_nom  = serializers.SerializerMethodField()
    passager_telephone = serializers.SerializerMethodField()
    passager_note = serializers.SerializerMethodField()

    class Meta:
        model = Reservation
        fields = [
            'id', 'trajet_id',
            'depart', 'destination', 'date_depart',
            'prix_par_place',
            'conducteur', 'conducteur_note',
            'passager_nom', 'passager_telephone', 'passager_note',
            'statut', 'date_reservation',
        ]

    def get_conducteur(self, obj):
        c = obj.trajet.conducteur
        return f"{c.first_name} {c.last_name}".strip() or c.username

    def get_conducteur_note(self, obj):
        return obj.trajet.conducteur.note

    def get_passager_nom(self, obj):
        p = obj.passager
        return f"{p.first_name} {p.last_name}".strip() or p.username

    def get_passager_telephone(self, obj):
        return getattr(obj.passager, 'telephone', None)

    def get_passager_note(self, obj):
        return obj.passager.note


class ReservationCreateSerializer(serializers.Serializer):
    """Création — reçoit juste le trajet_id."""
    trajet_id = serializers.IntegerField()