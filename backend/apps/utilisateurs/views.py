from rest_framework import viewsets, status, serializers as drf_serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.throttling import AnonRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate

from ..modeles.models import Utilisateur, Vehicule, Conducteur, Passager, PLACES_MAX_PAR_TYPE
from .serializers import InscriptionSerializer, ConnexionSerializer, UtilisateurSerializer, ChangePasswordSerializer
from .tokens import KovoitRefreshToken


class AuthRateThrottle(AnonRateThrottle):
    """5 tentatives/minute sur les endpoints login et inscription."""
    scope = 'auth'


def get_tokens(utilisateur):
    """Génère access + refresh token incluant les claims role et peut_conduire."""
    refresh = KovoitRefreshToken.for_user(utilisateur)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


class AuthViewSet(viewsets.GenericViewSet):
    """
    ViewSet pour l'inscription et la connexion.
    POST /api/utilisateurs/auth/inscription/
    POST /api/utilisateurs/auth/connexion/
    POST /api/utilisateurs/auth/deconnexion/
    POST /api/utilisateurs/auth/refresh/
    """
    permission_classes = [AllowAny]
    throttle_classes   = [AuthRateThrottle]

    def get_serializer_class(self):
        if self.action == 'inscription':
            return InscriptionSerializer
        return ConnexionSerializer

    @action(detail=False, methods=['post'])
    def inscription(self, request):
        serializer = InscriptionSerializer(data=request.data)
        if serializer.is_valid():
            utilisateur = serializer.save()
            tokens = get_tokens(utilisateur)
            return Response({
                "message": "Inscription réussie.",
                "utilisateur": UtilisateurSerializer(utilisateur).data,
                "tokens": tokens
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'])
    def connexion(self, request):
        serializer = ConnexionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        try:
            user_obj = Utilisateur.objects.get(email=email)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Identifiants invalides."}, status=status.HTTP_401_UNAUTHORIZED)

        utilisateur = authenticate(request, username=user_obj.username, password=password)

        if not utilisateur:
            return Response({"error": "Identifiants invalides."}, status=status.HTTP_401_UNAUTHORIZED)

        tokens = get_tokens(utilisateur)
        return Response({
            "message": "Connexion réussie.",
            "utilisateur": UtilisateurSerializer(utilisateur).data,
            "tokens": tokens
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def deconnexion(self, request):
        """Blackliste le refresh token."""
        try:
            refresh_token = request.data.get("refresh")
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({"message": "Déconnexion réussie."}, status=status.HTTP_200_OK)
        except Exception:
            return Response({"error": "Token invalide."}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'])
    def refresh(self, request):
        """Renouvelle l'access token via le refresh token."""
        try:
            refresh_token = request.data.get("refresh")
            token = RefreshToken(refresh_token)
            return Response({
                "access": str(token.access_token)
            }, status=status.HTTP_200_OK)
        except Exception:
            return Response({"error": "Refresh token invalide ou expiré."}, status=status.HTTP_400_BAD_REQUEST)


class UtilisateurViewSet(viewsets.GenericViewSet):
    """
    GET    /api/utilisateurs/ko/profil/        → profil connecté
    PUT    /api/utilisateurs/ko/profil/  → modifier profil
    PATCH  /api/utilisateurs/ko/profil/  → modifier profil
    DELETE /api/utilisateurs/ko/profil/  → modifier profil
    """
    permission_classes = [IsAuthenticated]
    serializer_class = UtilisateurSerializer
    queryset = Utilisateur.objects.all()

    @action(detail=False, methods=['get'])
    def profil(self, request):
        serializer = UtilisateurSerializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['put', 'patch'], url_path='profil/update')
    def update_profil(self, request):
        serializer = UtilisateurSerializer(
            request.user,
            data=request.data,
            partial=request.method == 'PATCH'
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], url_path='profil/change-password')
    def change_password(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        current_password = serializer.validated_data['current_password']
        new_password = serializer.validated_data['new_password']

        if not request.user.check_password(current_password):
            return Response({
                'current_password': 'Mot de passe actuel incorrect.'
            }, status=status.HTTP_400_BAD_REQUEST)

        request.user.set_password(new_password)
        request.user.save()
        return Response({"message": "Mot de passe mis à jour avec succès."}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['delete'], url_path='profil/delete')
    def delete_profil(self, request):
        """Supprime le compte de l'utilisateur connecté."""
        utilisateur = request.user
        try:
            # Blackliste le refresh token avant suppression
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
        except Exception:
            pass  # On supprime quand même même si le token est invalide

        utilisateur.delete()
        return Response({"message": "Compte supprimé avec succès."}, status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['delete'], url_path='delete', permission_classes=[IsAdminUser])
    def delete_utilisateur(self, request, pk=None):
        """Supprime un utilisateur par son ID (admin seulement)."""
        try:
            utilisateur = Utilisateur.objects.get(pk=pk)
            utilisateur.delete()
            return Response({"message": f"Utilisateur {utilisateur.username} supprimé."},
                            status=status.HTTP_204_NO_CONTENT)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Utilisateur introuvable."}, status=status.HTTP_404_NOT_FOUND)
        
    @action(detail=False, methods=['get'], url_path='vehicules')
    def vehicules(self, request):
        try:
            conducteur = request.user.profil_conducteur
        except Exception:
            return Response({"error": "Profil conducteur introuvable."}, status=403)
 
        vehicules = Vehicule.objects.filter(conducteur=conducteur).order_by('created_at')
        data = [{
            "id":            v.id,
            "type_vehicule": v.type_vehicule,
            "marque":        v.marque,
            "modele":        v.modele,
            "couleur":       v.couleur,
            "plaque":        v.plaque,
            "places_max":    v.places_max,
            "est_actif":     v.est_actif,
        } for v in vehicules]
        return Response(data)
 
    # ── Ajouter un véhicule ───────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='vehicules/ajouter')
    def ajouter_vehicule(self, request):
        try:
            conducteur = request.user.profil_conducteur
        except Exception:
            return Response({"error": "Profil conducteur introuvable."}, status=403)
 
        required = ['type_vehicule', 'marque', 'modele', 'couleur', 'plaque']
        for field in required:
            if not request.data.get(field):
                return Response({field: "Ce champ est requis."}, status=400)
 
        type_v = request.data.get('type_vehicule')
        if type_v not in PLACES_MAX_PAR_TYPE:
            return Response({"type_vehicule": "Type invalide. Choisir parmi : moto, voiture, minibus, camion."}, status=400)
 
        if Vehicule.objects.filter(plaque=request.data.get('plaque')).exists():
            return Response({"plaque": "Cette plaque est déjà enregistrée."}, status=400)
 
        vehicule = Vehicule.objects.create(
            conducteur=conducteur,
            type_vehicule=type_v,
            marque=request.data.get('marque'),
            modele=request.data.get('modele'),
            couleur=request.data.get('couleur'),
            plaque=request.data.get('plaque'),
            places_max=request.data.get('places_max') or PLACES_MAX_PAR_TYPE[type_v],
        )
        return Response({
            "id":            vehicule.id,
            "type_vehicule": vehicule.type_vehicule,
            "marque":        vehicule.marque,
            "modele":        vehicule.modele,
            "couleur":       vehicule.couleur,
            "plaque":        vehicule.plaque,
            "places_max":    vehicule.places_max,
            "est_actif":     vehicule.est_actif,
        }, status=201)
 
    # ── Upload CNI / Permis ───────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='upload-documents')
    def upload_documents(self, request):
        """
        Upload photo_cni et/ou photo_permis.
        Passe statut_validation à 'en_attente' dès qu'un document est reçu.
        """
        user = request.user
        recu = False

        if 'photo_cni' in request.FILES:
            user.photo_cni = request.FILES['photo_cni']
            recu = True
        if 'photo_permis' in request.FILES:
            user.photo_permis = request.FILES['photo_permis']
            recu = True

        if not recu:
            return Response({"error": "Aucun document fourni."}, status=status.HTTP_400_BAD_REQUEST)

        user.statut_validation = 'en_attente'
        user.save()
        return Response({
            "message": "Documents uploadés. En attente de validation par l'administrateur.",
            "statut_validation": user.statut_validation,
        })

    # ── Bascule Passager → Conducteur ─────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='basculer-role')
    def basculer_role(self, request):
        """
        Permet à un passager de devenir conducteur.
        Crée le profil Conducteur + un premier véhicule.
        Passe le rôle à 'conducteur' et statut_validation à 'en_attente'.
        """
        user = request.user

        if user.role != Utilisateur.Role.PASSAGER:
            return Response(
                {"error": "Seuls les passagers peuvent demander un changement de rôle."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Champs conducteur obligatoires
        numero_permis     = request.data.get('numero_permis', '').strip()
        experience_annees = int(request.data.get('experience_annees', 0))

        if not numero_permis:
            return Response({"error": "Le numéro de permis est requis."}, status=status.HTTP_400_BAD_REQUEST)

        # Champs véhicule obligatoires
        type_vehicule = request.data.get('type_vehicule', '').strip()
        marque        = request.data.get('marque', '').strip()
        modele        = request.data.get('modele', '').strip()
        couleur       = request.data.get('couleur', '').strip()
        plaque        = request.data.get('plaque', '').strip()

        if not all([type_vehicule, marque, modele, couleur, plaque]):
            return Response(
                {"error": "Tous les champs du véhicule sont requis (type, marque, modèle, couleur, plaque)."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if type_vehicule not in PLACES_MAX_PAR_TYPE:
            return Response(
                {"type_vehicule": "Type invalide. Choisir parmi : moto, voiture, minibus, camion."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if Vehicule.objects.filter(plaque=plaque).exists():
            return Response({"plaque": "Cette plaque est déjà enregistrée."}, status=status.HTTP_400_BAD_REQUEST)

        # Upload documents si fournis
        if 'photo_cni' in request.FILES:
            user.photo_cni = request.FILES['photo_cni']
        if 'photo_permis' in request.FILES:
            user.photo_permis = request.FILES['photo_permis']

        # Changer le rôle et passer en attente
        user.role = 'conducteur'
        user.statut_validation = 'en_attente'
        user.save()

        # Créer le profil conducteur (idempotent)
        conducteur, _ = Conducteur.objects.get_or_create(
            utilisateur=user,
            defaults={
                'numero_permis':     numero_permis,
                'experience_annees': experience_annees,
            }
        )

        # Créer le premier véhicule
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

        return Response({
            "message": "Demande de bascule soumise avec succès. En attente de validation admin.",
            "utilisateur": UtilisateurSerializer(user).data,
        }, status=status.HTTP_200_OK)

    # ── Basculement rapide de mode (conducteur ↔ passager) ────────────────
    @action(detail=False, methods=['post'], url_path='changer-mode')
    def changer_mode(self, request):
        """
        Permet à un utilisateur validé (peut_conduire=True) de basculer
        entre le mode passager et conducteur SANS re-soumettre de documents.
        """
        user = request.user

        if not user.peut_conduire:
            return Response(
                {"error": "Votre dossier conducteur n'a pas encore été validé par un administrateur."},
                status=status.HTTP_403_FORBIDDEN
            )

        Role = Utilisateur.Role

        if user.role == Role.PASSAGER:
            if not hasattr(user, 'profil_conducteur'):
                return Response(
                    {"error": "Profil conducteur introuvable. Soumettez d'abord un dossier."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            user.role = Role.CONDUCTEUR
            user.save(update_fields=['role'])
            return Response({
                "message": "Mode conducteur activé.",
                "role": user.role,
                "utilisateur": UtilisateurSerializer(user).data,
            })

        elif user.role == Role.CONDUCTEUR:
            if not hasattr(user, 'profil_passager'):
                Passager.objects.create(utilisateur=user)
            user.role = Role.PASSAGER
            user.save(update_fields=['role'])
            return Response({
                "message": "Mode passager activé.",
                "role": user.role,
                "utilisateur": UtilisateurSerializer(user).data,
            })

        return Response(
            {"error": "Rôle non supporté pour le basculement."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ── Désactiver un véhicule ────────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='desactiver')
    def desactiver_vehicule(self, request, pk=None):
        try:
            conducteur = request.user.profil_conducteur
            vehicule   = Vehicule.objects.get(pk=pk, conducteur=conducteur)
        except Vehicule.DoesNotExist:
            return Response({"error": "Véhicule introuvable."}, status=404)
        except Exception:
            return Response({"error": "Non autorisé."}, status=403)
 
        vehicule.est_actif = False
        vehicule.save()
        return Response({"message": "Véhicule désactivé."})