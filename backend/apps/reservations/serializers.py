from rest_framework import serializers
from ..modeles.models import Reservation


class ReservationSerializer(serializers.ModelSerializer):
    """Lecture — utilisé pour afficher les réservations."""

    # Infos trajet
    depart         = serializers.CharField(source='trajet.depart',            read_only=True)
    destination    = serializers.CharField(source='trajet.destination',       read_only=True)
    date_depart    = serializers.DateTimeField(source='trajet.date_heure_depart', read_only=True)
    prix_par_place = serializers.DecimalField(
        source='trajet.prix_par_place', max_digits=10, decimal_places=2, read_only=True
    )
    trajet_statut   = serializers.CharField(source='trajet.statut',          read_only=True)
    trajet_distance = serializers.FloatField(source='trajet.distance_km',     read_only=True)
    depart_lat      = serializers.FloatField(source='trajet.depart_lat',      read_only=True, allow_null=True)
    depart_lng      = serializers.FloatField(source='trajet.depart_lng',      read_only=True, allow_null=True)
    destination_lat = serializers.FloatField(source='trajet.destination_lat', read_only=True, allow_null=True)
    destination_lng = serializers.FloatField(source='trajet.destination_lng', read_only=True, allow_null=True)
    conducteur_id   = serializers.CharField(source='trajet.conducteur.id',   read_only=True)

    # Infos conducteur
    conducteur           = serializers.SerializerMethodField()
    conducteur_note      = serializers.SerializerMethodField()
    conducteur_telephone = serializers.SerializerMethodField()

    # Infos passager (pour le conducteur)
    passager_id        = serializers.UUIDField(source='passager.id', read_only=True)
    passager_nom       = serializers.SerializerMethodField()
    passager_telephone = serializers.SerializerMethodField()
    passager_note      = serializers.SerializerMethodField()
    passager_photo     = serializers.SerializerMethodField()

    # Infos paiement (pour les deux parties)
    paiement_statut           = serializers.SerializerMethodField()
    paiement_moyen            = serializers.SerializerMethodField()
    paiement_reference_mobile = serializers.SerializerMethodField()

    # Lien vers la conversation messagerie
    conversation_id = serializers.SerializerMethodField()

    class Meta:
        model = Reservation
        fields = [
            'id', 'trajet_id',
            'depart', 'destination', 'date_depart',
            'prix_par_place', 'prix_passager',
            'conducteur', 'conducteur_note', 'conducteur_telephone',
            'passager_id', 'passager_nom', 'passager_telephone', 'passager_note', 'passager_photo',
            'statut', 'places_reservees', 'date_reservation',
            # Trajet (statut réel + coordonnées GPS)
            'trajet_statut', 'trajet_distance',
            'depart_lat', 'depart_lng', 'destination_lat', 'destination_lng',
            'conducteur_id',
            # Embarquement
            'code_embarquement', 'statut_embarquement',
            'heure_embarquement', 'heure_depose',
            'point_prise_en_charge', 'point_depose',
            'distance_passager', 'penalite_annulation',
            # Paiement
            'paiement_statut', 'paiement_moyen', 'paiement_reference_mobile',
            # Messagerie
            'conversation_id',
        ]

    def get_conducteur(self, obj):
        c = obj.trajet.conducteur
        return f"{c.first_name} {c.last_name}".strip() or c.username

    def get_conducteur_note(self, obj):
        return obj.trajet.conducteur.note

    def get_conducteur_telephone(self, obj):
        return obj.trajet.conducteur.numero_telephone or ''

    def get_passager_nom(self, obj):
        p = obj.passager
        return f"{p.first_name} {p.last_name}".strip() or p.username

    def get_passager_telephone(self, obj):
        return obj.passager.numero_telephone or ''

    def get_passager_note(self, obj):
        return obj.passager.note

    def get_passager_photo(self, obj):
        try:
            photo = obj.passager.photo_profil
            if photo:
                request = self.context.get('request')
                return request.build_absolute_uri(photo.url) if request else photo.url
        except Exception:
            pass
        return None

    def _get_paiement(self, obj):
        try:
            return obj.paiement
        except Exception:
            return None

    def get_paiement_statut(self, obj):
        p = self._get_paiement(obj)
        return p.statut if p else None

    def get_paiement_moyen(self, obj):
        p = self._get_paiement(obj)
        return p.moyen_paiement if p else None

    def get_paiement_reference_mobile(self, obj):
        p = self._get_paiement(obj)
        return p.reference_mobile if p else None

    def get_conversation_id(self, obj):
        try:
            return obj.conversation.id
        except Exception:
            return None


class ReservationConducteurSerializer(ReservationSerializer):
    """Vue conducteur — sans le code_embarquement du passager (sécurité)."""

    class Meta(ReservationSerializer.Meta):
        fields = [f for f in ReservationSerializer.Meta.fields
                  if f != 'code_embarquement']


class ReservationCreateSerializer(serializers.Serializer):
    """Création d'une réservation, avec coordonnées de prise en charge optionnelles."""
    trajet_id           = serializers.IntegerField()
    # Prise en charge passager (optionnel — pour tarification proportionnelle)
    point_prise_en_charge = serializers.CharField(required=False, allow_blank=True, default='')
    prise_en_charge_lat   = serializers.FloatField(required=False, allow_null=True, default=None)
    prise_en_charge_lng   = serializers.FloatField(required=False, allow_null=True, default=None)
    point_depose          = serializers.CharField(required=False, allow_blank=True, default='')
    depose_lat            = serializers.FloatField(required=False, allow_null=True, default=None)
    depose_lng            = serializers.FloatField(required=False, allow_null=True, default=None)