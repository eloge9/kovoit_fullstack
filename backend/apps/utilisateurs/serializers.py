from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from ..modeles.models import Utilisateur, Conducteur, Passager, Admin, Vehicule, PLACES_MAX_PAR_TYPE


class VehiculeSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Vehicule
        fields = ['id', 'type_vehicule', 'marque', 'modele', 'couleur', 'plaque',
                  'places_max', 'est_actif', 'photo_carte_grise']
        extra_kwargs = {'photo_carte_grise': {'required': False, 'allow_null': True}}


class ConducteurSerializer(serializers.ModelSerializer):
    vehicules = VehiculeSerializer(many=True, read_only=True)

    class Meta:
        model   = Conducteur
        exclude = ['utilisateur']


class PassagerSerializer(serializers.ModelSerializer):
    class Meta:
        model   = Passager
        exclude = ['utilisateur']


class AdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Admin
        fields = ['permissions_specifiques']


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

        Role = Utilisateur.Role

        if utilisateur.role == Role.CONDUCTEUR:
            conducteur = Conducteur.objects.create(
                utilisateur=utilisateur,
                numero_permis=numero_permis,
                experience_annees=experience_annees,
            )
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
            # Créer le profil de vérification dès l'inscription
            try:
                from apps.verification.models import DriverProfile, VerificationHistory, DriverStatus
                profile = DriverProfile.objects.create(
                    user=utilisateur,
                    numero_permis=numero_permis,
                    experience_annees=experience_annees,
                    status=DriverStatus.DOCUMENTS_MISSING,
                )
                VerificationHistory.objects.create(
                    driver_profile=profile,
                    old_status="",
                    new_status=DriverStatus.DOCUMENTS_MISSING,
                    reason="Création du compte conducteur",
                    is_automatic=True,
                )
            except Exception:
                pass  # Ne pas bloquer l'inscription si le module vérification échoue

        elif utilisateur.role == Role.PASSAGER:
            Passager.objects.create(utilisateur=utilisateur)

        elif utilisateur.role == Role.ADMIN:
            Admin.objects.create(utilisateur=utilisateur)

        return utilisateur


# ---------- Connexion ----------
class ConnexionSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password     = serializers.CharField(write_only=True, validators=[validate_password])
    new_password2    = serializers.CharField(write_only=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password2']:
            raise serializers.ValidationError({
                'new_password': 'Les mots de passe ne correspondent pas.'
            })
        return attrs


# ---------- Utilisateur (lecture) ----------
class UtilisateurSerializer(serializers.ModelSerializer):
    profil_conducteur   = ConducteurSerializer(read_only=True)
    profil_passager     = PassagerSerializer(read_only=True)
    profil_admin        = AdminSerializer(read_only=True)
    driver_status       = serializers.SerializerMethodField()
    is_driver_verified  = serializers.SerializerMethodField()
    driver_profile_id   = serializers.SerializerMethodField()

    class Meta:
        model  = Utilisateur
        fields = [
            'id', 'username', 'first_name', 'last_name',
            'email', 'role', 'numero_telephone',
            'photo_profil', 'note', 'is_active',
            'date_joined', 'last_login',
            'photo_cni', 'photo_permis', 'statut_validation', 'peut_conduire',
            'contact_urgence_nom', 'contact_urgence_telephone',
            'profil_conducteur', 'profil_passager', 'profil_admin',
            # Champs vérification conducteur
            'driver_status', 'is_driver_verified', 'driver_profile_id',
        ]
        extra_kwargs = {
            'photo_profil': {'required': False, 'allow_null': True},
            'photo_cni':    {'required': False, 'allow_null': True},
            'photo_permis': {'required': False, 'allow_null': True},
            'username': {'required': False},
            'email':    {'required': False},
            'role':     {'required': False},
        }

    def get_driver_status(self, obj):
        try:
            return obj.driver_profile.status
        except Exception:
            return 'DOCUMENTS_MISSING' if obj.role == 'conducteur' else None

    def get_is_driver_verified(self, obj):
        try:
            return obj.driver_profile.is_verified
        except Exception:
            return False

    def get_driver_profile_id(self, obj):
        try:
            return str(obj.driver_profile.id)
        except Exception:
            return None