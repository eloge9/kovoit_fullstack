from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from ..modeles.models import Utilisateur, Conducteur, Passager, Admin


class ConducteurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Conducteur
        exclude = ['utilisateur']


class PassagerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Passager
        exclude = ['utilisateur']


# ---------- Inscription ----------
class InscriptionSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True)

    # ✅ Champs conducteur à PLAT (pas imbriqués)
    numero_permis = serializers.CharField(required=False, allow_blank=True)
    vehicule = serializers.CharField(required=False, allow_blank=True)
    couleur_vehicule = serializers.CharField(required=False, allow_blank=True)
    type_vehicule = serializers.CharField(required=False, allow_blank=True)
    plaque = serializers.CharField(required=False, allow_blank=True)
    experience_annees = serializers.IntegerField(required=False, default=0)

    class Meta:
        model = Utilisateur
        fields = [
            'username', 'email', 'password', 'password2',
            'role', 'numero_telephone', 'photo_profil',
            # champs conducteur à plat
            'numero_permis', 'vehicule', 'couleur_vehicule',
            'type_vehicule', 'plaque', 'experience_annees',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password2'):
            raise serializers.ValidationError(
                {"password": "Les mots de passe ne correspondent pas."}
            )

        role = attrs.get('role')
        if role == 'conducteur':
            required = ['numero_permis', 'vehicule', 'couleur_vehicule', 'type_vehicule', 'plaque']
            for field in required:
                if not attrs.get(field):
                    raise serializers.ValidationError(
                        {field: "Ce champ est requis pour un conducteur."}
                    )

        return attrs

    def create(self, validated_data):
        # Extraire les champs conducteur avant création user
        conducteur_data = {
            'numero_permis':    validated_data.pop('numero_permis', ''),
            'vehicule':         validated_data.pop('vehicule', ''),
            'couleur_vehicule': validated_data.pop('couleur_vehicule', ''),
            'type_vehicule':    validated_data.pop('type_vehicule', ''),
            'plaque':           validated_data.pop('plaque', ''),
            'experience_annees':validated_data.pop('experience_annees', 0),
        }

        utilisateur = Utilisateur.objects.create_user(**validated_data)

        if utilisateur.role == 'conducteur':
            Conducteur.objects.create(utilisateur=utilisateur, **conducteur_data)
        elif utilisateur.role == 'passager':
            Passager.objects.create(utilisateur=utilisateur)
        elif utilisateur.role == 'admin':
            Admin.objects.create(utilisateur=utilisateur)

        return utilisateur


# ---------- Connexion ----------
class ConnexionSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


# ---------- Utilisateur (lecture) ----------
class UtilisateurSerializer(serializers.ModelSerializer):
    profil_conducteur = ConducteurSerializer(read_only=True)
    profil_passager = PassagerSerializer(read_only=True)

    class Meta:
        model = Utilisateur
        fields = [
            'id', 'username', 'email', 'role',
            'numero_telephone', 'photo_profil', 'note',
            'profil_conducteur', 'profil_passager'
        ]