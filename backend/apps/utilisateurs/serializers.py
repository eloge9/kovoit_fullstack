from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from ..modeles.models import Utilisateur, Conducteur, Passager, Admin, Vehicule, PLACES_MAX_PAR_TYPE


class VehiculeSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Vehicule
        fields = ['id', 'type_vehicule', 'marque', 'modele', 'couleur', 'plaque', 'places_max', 'est_actif']


class ConducteurSerializer(serializers.ModelSerializer):
    vehicules = VehiculeSerializer(many=True, read_only=True)

    class Meta:
        model   = Conducteur
        exclude = ['utilisateur']


class PassagerSerializer(serializers.ModelSerializer):
    class Meta:
        model   = Passager
        exclude = ['utilisateur']


# ---------- Inscription ----------
class InscriptionSerializer(serializers.ModelSerializer):
    password  = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True)

    # Champs conducteur
    numero_permis     = serializers.CharField(required=False, allow_blank=True)
    experience_annees = serializers.IntegerField(required=False, default=0)

    # Champs premier véhicule (obligatoires si conducteur)
    type_vehicule = serializers.ChoiceField(
        choices=['moto', 'voiture', 'minibus', 'camion'],
        required=False
    )
    marque  = serializers.CharField(required=False, allow_blank=True)
    modele  = serializers.CharField(required=False, allow_blank=True)
    couleur = serializers.CharField(required=False, allow_blank=True)
    plaque  = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model  = Utilisateur
        fields = [
            'username', 'email', 'password', 'password2',
            'first_name', 'last_name',
            'role', 'numero_telephone', 'photo_profil',
            # conducteur
            'numero_permis', 'experience_annees',
            # véhicule
            'type_vehicule', 'marque', 'modele', 'couleur', 'plaque',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password2'):
            raise serializers.ValidationError({"password": "Les mots de passe ne correspondent pas."})

        if attrs.get('role') == 'conducteur':
            required_conducteur = ['numero_permis']
            required_vehicule   = ['type_vehicule', 'marque', 'modele', 'couleur', 'plaque']
            for field in required_conducteur + required_vehicule:
                if not attrs.get(field):
                    raise serializers.ValidationError({field: "Ce champ est requis pour un conducteur."})

        return attrs

    def create(self, validated_data):
        # Extraire données conducteur
        numero_permis     = validated_data.pop('numero_permis', '')
        experience_annees = validated_data.pop('experience_annees', 0)

        # Extraire données véhicule
        type_vehicule = validated_data.pop('type_vehicule', None)
        marque        = validated_data.pop('marque', '')
        modele        = validated_data.pop('modele', '')
        couleur       = validated_data.pop('couleur', '')
        plaque        = validated_data.pop('plaque', '')

        utilisateur = Utilisateur.objects.create_user(**validated_data)

        if utilisateur.role == 'conducteur':
            conducteur = Conducteur.objects.create(
                utilisateur=utilisateur,
                numero_permis=numero_permis,
                experience_annees=experience_annees,
            )
            # Créer le premier véhicule automatiquement
            places_max = PLACES_MAX_PAR_TYPE.get(type_vehicule, 4)
            Vehicule.objects.create(
                conducteur=conducteur,
                type_vehicule=type_vehicule,
                marque=marque,
                modele=modele,
                couleur=couleur,
                plaque=plaque,
                places_max=places_max,
            )

        elif utilisateur.role == 'passager':
            Passager.objects.create(utilisateur=utilisateur)

        elif utilisateur.role == 'admin':
            Admin.objects.create(utilisateur=utilisateur)

        return utilisateur


# ---------- Connexion ----------
class ConnexionSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(write_only=True)


# ---------- Utilisateur (lecture) ----------
class UtilisateurSerializer(serializers.ModelSerializer):
    profil_conducteur = ConducteurSerializer(read_only=True)
    profil_passager   = PassagerSerializer(read_only=True)

    class Meta:
        model  = Utilisateur
        fields = [
            'id', 'username', 'first_name', 'last_name',
            'email', 'role', 'numero_telephone',
            'photo_profil', 'note',
            'profil_conducteur', 'profil_passager',
        ]
        extra_kwargs = {
            'photo_profil': {'required': False, 'allow_null': True},
            'username': {'required': False},
            'email': {'required': False},
            'role': {'required': False},
        }